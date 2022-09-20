package main

// TODO Run schema migrations on live database

import (
	"database/sql"
	"fmt"
	"os"
	"os/signal"
	"reflect"
	"strconv"
	"strings"
	"syscall"
	"time"

	"github.com/bwmarrin/discordgo"
	_ "github.com/mattn/go-sqlite3"
	log "github.com/sirupsen/logrus"
)

var DB *sql.DB

func main() {
	log.Info("Initializing...")
	log.SetReportCaller(true)
	log.SetLevel(log.DebugLevel)

	InCI, InCIExist := os.LookupEnv("CI")
	if InCIExist && InCI == "true" {
		log.Fatal("Running in CI.  This proves functionality?")
		os.Exit(0)
	}

	Token, tokenExists := os.LookupEnv("APPROOVA_DISCORD_TOKEN")
	if !tokenExists {
		log.Fatal("APPROOVA_DISCORD_TOKEN is not set.  Exiting.")
		os.Exit(2)
	}

	// Create database and tables as needed
	setupDb()

	// Create a new Discord session using the provided bot token.
	dg, err := discordgo.New("Bot " + Token)
	if err != nil {
		log.Fatal("error creating Discord session,", err)
		os.Exit(3)
	}

	dg.AddHandler(messageCreate)
	dg.AddHandler(guildMemberAdd)
	dg.AddHandler(messageReactionAdd)

	dg.Identify.Intents = discordgo.IntentsAllWithoutPrivileged | discordgo.IntentsGuildMembers | discordgo.IntentMessageContent

	// Open a websocket connection to Discord and begin listening.
	err = dg.Open()
	if err != nil {
		log.Fatal("Error opening websocket connection,", err)
		os.Exit(4)
	}

	// Wait here until CTRL-C or other term signal is received.
	log.Info("Approova is online!")
	sc := make(chan os.Signal, 1)
	signal.Notify(sc, syscall.SIGINT, syscall.SIGTERM, os.Interrupt)
	<-sc

	// Cleanly close down the Discord session.
	dg.Close()
}

func setupDb() {
	log.Info("Initializing database...")
	db_path, db_path_env_var_is_set := os.LookupEnv("APPROOVA_DB_PATH")
	if !db_path_env_var_is_set {
		db_path = "sqlite.db"
	}

	// Create db file if it doesn't exist
	if _, err := os.Stat(db_path); os.IsNotExist(err) {
		file, err := os.Create(db_path)
		if err != nil {
			log.Fatal("Error creating database file,", err)
			os.Exit(5)
		}
		file.Close()
	}

	db, err := sql.Open("sqlite3", db_path)
	if err != nil {
		log.Fatal("Error opening database", err)
	}
	log.Debug("Database file opened")
	DB = db

	// TODO do schema migrations
	log.Debug("Setting up database schema")
	err = setupDbSchema()
	if err != nil {
		log.Fatal("Error setting up database schema,", err)
		os.Exit(6)
	}
	log.Debug("Schema setup completed")

	log.Info("Database initialized")
}

func setupDbSchema() error {
	createTablesQueries := make([]string, 5)
	createTablesQueries[0] = `
		CREATE TABLE IF NOT EXISTS approval_pubrole (
			guild_id TEXT UNIQUE,
			pubrole TEXT PRIMARY KEY
		);`

	createTablesQueries[1] = `
		CREATE TABLE IF NOT EXISTS approval_channel (
			guild_id TEXT UNIQUE,
			channel TEXT PRIMARY KEY
		);`

	createTablesQueries[2] = `
		CREATE TABLE IF NOT EXISTS approval_role (
			guild_id TEXT UNIQUE,
			role TEXT PRIMARY KEY
		);`

	createTablesQueries[3] = `
		CREATE TABLE IF NOT EXISTS approval_pubchannel (
			guild_id TEXT UNIQUE,
			pubchannel TEXT PRIMARY KEY
		);`

	createTablesQueries[4] = `
		CREATE TABLE IF NOT EXISTS pending_approvals (
			guild_id TEXT,
			message_id TEXT PRIMARY KEY,
			member_id TEXT
		);`

	for _, query := range createTablesQueries {
		log.Debugf("Preparing migration query: %s", query)

		stmt, err := DB.Prepare(query)
		if err != nil {
			return err
		}

		log.Debug("Executing migration query")
		_, err = stmt.Exec()
		if err != nil {
			return err
		}
	}
	return nil
}

// messageReactionAdd is the event handler for when a reaction is added to a message.
func messageReactionAdd(s *discordgo.Session, r *discordgo.MessageReactionAdd) {
	// Ignore all reactions created by the bot itself
	if r.UserID == s.State.User.ID {
		return
	}

	// Ignore if the guild isn't configured
	if !isGuildConfigured(r.GuildID) {
		log.Debugf("Skipping messageReactionAdd event for guild %s because it is not configured", r.GuildID)
	}

	// Ignore all reactions that aren't in the approver channel
	pubrole, pubchannel, role, channel, err := getGuildConfig(r.GuildID)
	if err != nil {
		log.Errorf("Error getting guild config for guild %s: %s", r.GuildID, err)
		return
	}
	if r.ChannelID != channel {
		log.Debugf("Skipping messageReactionAdd event for guild %s because it is not in the approver channel", r.GuildID)
		return
	}

	// Ignore all reactions that aren't the checkmark emoji
	if r.Emoji.Name != "✅" {
		log.Debugf("Skipping messageReactionAdd event for guild %s because it is not the checkmark emoji", r.GuildID)
		return
	}

	// Ignore all reactions that aren't in the pending approvals table
	member_id := ""
	err = DB.QueryRow("SELECT member_id FROM pending_approvals WHERE guild_id = ? AND message_id = ?", r.GuildID, r.MessageID).Scan(&member_id)
	if err != nil {
		log.Errorf("Skipping messageReactionAdd event for guild %s because message %s is not in the pending approvals table", r.MessageID, r.GuildID)
		return
	}

	// Ignore all reactions that aren't from the approver role
	member, err := s.GuildMember(r.GuildID, r.UserID)
	if err != nil {
		log.Errorf("Skipping messageReactionAdd event for guild %s because an error occured retrieving approving user %s", r.GuildID, r.UserID)
		return
	}
	isApprover := false
	for _, roleID := range member.Roles {
		if roleID == role {
			isApprover = true
			break
		}
	}
	if !isApprover {
		log.Debugf("Skipping messageReactionAdd event for guild %s because user %s is not an approver", r.GuildID, r.UserID)
		return
	}

	// Process the approval
	log.Infof("Processing approval for guild %s, member %s, approving member %s", r.GuildID, member_id, r.UserID)

	// Add the role to the member
	err = s.GuildMemberRoleAdd(r.GuildID, member_id, pubrole)
	if err != nil {
		log.Errorf("Error adding role %s to member %s for guild %s: %s", role, member_id, r.GuildID, err)
		respondError(s, channel)
		return
	}

	approvedMsg := fmt.Sprintf("<@%s> approved <@%s>", r.UserID, member_id)
	_, err = s.ChannelMessageSend(pubchannel, approvedMsg)
	if err != nil {
		log.Errorf("Error sending approval message to public channel %s for guild %s: %s", pubchannel, r.GuildID, err)
		return
	}

	_, err = DB.Exec("DELETE FROM pending_approvals WHERE guild_id = ? AND member_id = ?", r.GuildID, member_id)
	if err != nil {
		log.Errorf("An error occured deleting from pending_approvals for guild_id=%s and member_id=%s, %s", r.GuildID, member_id, err)
		return
	}

}

// guildMemberAdd is the event handler for when a new member joins the guild.
func guildMemberAdd(s *discordgo.Session, m *discordgo.GuildMemberAdd) {
	log.Debugf("Received guildMemberAdd event for member %s in guild %s", m.User.ID, m.GuildID)
	if !isGuildConfigured(m.GuildID) {
		log.Debugf("Skipping guildMemberAdd event for guild %s because it is not configured", m.GuildID)
	}
	log.Debugf("Guild is configured, sending approval message to guild %s", m.GuildID)

	pubroleID, pubchannelID, _, channelID, err := getGuildConfig(m.GuildID)
	if err != nil {
		log.Errorf("Error getting guild config for guild %s: %s", m.GuildID, err)
		return
	}

	pubRoleObj, err := s.State.Role(m.GuildID, pubroleID)
	if err != nil {
		log.Errorf("Failed to get public role name (%s) for guild %s. %s", pubroleID, m.GuildID, err)
		return
	}
	pubroleName := pubRoleObj.Name
	welcomeMsg := fmt.Sprintf("Welcome <@%s> - You have been placed in queue for approval to more channels.  You may use public channels until you are approved as %s.", m.User.ID, pubroleName)
	approvalMsg := fmt.Sprintf("<@%s> has joined the server.  You may grant them access to all rooms by clicking the check under this message.", m.User.ID)

	_, err = s.ChannelMessageSend(pubchannelID, welcomeMsg)
	if err != nil {
		log.Errorf("Failed to send welcome message for guild %s, member %s, channel %s. %s", m.GuildID, m.User.ID, pubchannelID, err)
		return
	}

	approvalMsgObj, err := s.ChannelMessageSend(channelID, approvalMsg)
	if err != nil {
		log.Errorf("Failed to send approval message for guild %s, member %s, channel %s. %s", m.GuildID, m.User.ID, channelID, err)
		return
	}

	approvalMsgID := approvalMsgObj.ID
	err = s.MessageReactionAdd(approvalMsgObj.ChannelID, approvalMsgID, "\u2705")
	if err != nil {
		log.Errorf("Failed to add reaction emoji to message id %s in guild %s. %s", approvalMsgID, m.GuildID, err)
		return
	}

	query := "INSERT INTO pending_approvals (guild_id, member_id, message_id) VALUES (?, ?, ?)"
	stmt, err := DB.Prepare(query)
	if err != nil {
		log.Errorf("Failed to prepare database statement (%s). %s", query, err)
		return
	}
	_, err = stmt.Exec(m.GuildID, m.User.ID, approvalMsgID)
	if err != nil {
		log.Errorf("Failed to execute database statement (%s) with guild %s, member %s, message %s. %s", query, m.GuildID, m.User.ID, approvalMsgID, err)
		return
	}

}

// isGuildConfigured returns true if the guild has all configuration properties set.
func isGuildConfigured(guildId string) bool {
	log.Debugf("Checking if guild %s is configured", guildId)

	_, _, _, _, err := getGuildConfig(guildId)
	if err != nil {
		return false
	}
	return true
}

// getGuildConfig returns the configuration for the guild.
// The return values are the IDs for the guild's pubrole, pubchannel, role, channel, and error.
func getGuildConfig(guildID string) (string, string, string, string, error) {
	log.Debugf("Getting config for guild %s", guildID)
	query := `SELECT
	approval_pubrole.pubrole AS pubrole,
	approval_pubchannel.pubchannel AS pubchannel,
	approval_role.role AS role,
	approval_channel.channel AS channel
FROM approval_pubrole
INNER JOIN approval_pubchannel USING (guild_id)
INNER JOIN approval_role USING (guild_id)
INNER JOIN approval_channel USING (guild_id)
WHERE guild_id = ?;
`

	log.Debugf("Preparing query %s", query)
	stm, err := DB.Prepare(query)
	if err != nil {
		log.Errorf("Error preparing config query for guild %s. %s", guildID, err)
		return "", "", "", "", err
	}

	pubrole := ""
	pubchannel := ""
	role := ""
	channel := ""
	defer stm.Close()
	log.Debugf("Executing query %s", query)
	err = stm.QueryRow(guildID).Scan(&pubrole, &pubchannel, &role, &channel)
	if err != nil {
		return pubrole, pubchannel, role, channel, err
	}
	return pubrole, pubchannel, role, channel, nil
}

// messageCreate handles new message events from Discord and routes them to the appropriate handler.
func messageCreate(s *discordgo.Session, m *discordgo.MessageCreate) {

	// Ignore all messages created by the bot itself
	if m.Author.ID == s.State.User.ID {
		return
	}

	if m.Content == "*help" {
		go helpCommand(s, m)
	} else if m.Content == "*ping" {
		go pingCommand(s, m)
	} else if m.Content == "*showConfig" {
		go showConfigCommand(s, m)
	} else if strings.Split(m.Content, " ")[0] == "*setApproverChannel" {
		go setApproverChannelCommand(s, m)
	} else if strings.Split(m.Content, " ")[0] == "*setPublicChannel" {
		go setPublicChannelCommand(s, m)
	} else if strings.Split(m.Content, " ")[0] == "*setApproverRole" {
		go setApproverRole(s, m)
	} else if strings.Split(m.Content, " ")[0] == "*setPublicRole" {
		go setPublicRole(s, m)
	}
}

// setPublicRole is the command handler to set the public role for the guild.
func setPublicRole(s *discordgo.Session, m *discordgo.MessageCreate) {
	log.Debugf("Received setPublicRole command from %s", m.Author.ID)
	responseMsg := ""
	if !isGuildOwner(s, m) {
		responseMsg = "You're not the guild owner, you can't do that!"
		respond(s, m.ChannelID, responseMsg)
		return
	} else {
		log.Debugf("Owner validation passed for author %s in guild %s", m.Author.ID, m.GuildID)
	}

	inputRole := strings.Join(strings.Split(m.Content, " ")[1:], " ")
	log.Debugf("Setting public role to %s for guild %s", inputRole, m.GuildID)
	if isLink(inputRole) {
		inputRole = stripLink(inputRole)
	} else {
		// Find channel by name
		roles, err := s.GuildRoles(m.GuildID)
		if err != nil {
			log.Errorf("Failed to get guild %s channels. %s", m.GuildID, err)
			respondError(s, m.ChannelID)
			return
		}
		for _, r := range roles {
			if r.Name == inputRole {
				inputRole = r.ID
				break
			}
		}
	}
	publicRole, err := s.State.Role(m.GuildID, inputRole)
	if err != nil {
		log.Errorf("Failed to get public role %s in guild %s. %s", inputRole, m.GuildID, err)
		respondError(s, m.ChannelID)
		return
	}

	query := "INSERT OR REPLACE INTO approval_pubrole (guild_id, pubrole) VALUES (?, ?)"
	stmt, err := DB.Prepare(query)
	if err != nil {
		log.Errorf("Failed to prepare database statement (%s). %s", query, err)
		respondError(s, m.ChannelID)
		return
	}
	_, err = stmt.Exec(m.GuildID, publicRole.ID)
	if err != nil {
		log.Errorf("Failed to execute database statement (%s) with guild %s and role %s. %s", query, m.GuildID, publicRole.ID, err)
		respondError(s, m.ChannelID)
		return
	}

	respond(s, m.ChannelID, "Configured public role to "+publicRole.Mention())
}

// setApproverRole is the command handler to set the approver role for the guild.
func setApproverRole(s *discordgo.Session, m *discordgo.MessageCreate) {
	log.Debugf("Received setApproverRole command from %s", m.Author.ID)
	responseMsg := ""
	if !isGuildOwner(s, m) {
		responseMsg = "You're not the guild owner, you can't do that!"
		_, err := s.ChannelMessageSend(m.ChannelID, responseMsg)
		if err != nil {
			log.Errorf("Failed to respond to setApproverRole command. %s", err)
		}
		return
	} else {
		log.Debugf("Owner validation passed for author %s in guild %s", m.Author.ID, m.GuildID)
	}

	inputRole := strings.Join(strings.Split(m.Content, " ")[1:], "")
	log.Debugf("Setting approver role to %s for guild %s", inputRole, m.GuildID)
	if isLink(inputRole) {
		inputRole = stripLink(inputRole)
	} else {
		// Find channel by name
		roles, err := s.GuildRoles(m.GuildID)
		if err != nil {
			log.Errorf("Failed to get guild %s channels. %s", m.GuildID, err)
			respondError(s, m.ChannelID)
			return
		}
		for _, r := range roles {
			if r.Name == inputRole {
				inputRole = r.ID
				break
			}
		}
	}
	approverRole, err := s.State.Role(m.GuildID, inputRole)
	if err != nil {
		log.Errorf("Failed to get approver role %s in guild %s. %s", inputRole, m.GuildID, err)
		respondError(s, m.ChannelID)
		return
	}

	query := "INSERT OR REPLACE INTO approval_role (guild_id, role) VALUES (?, ?)"
	stmt, err := DB.Prepare(query)
	if err != nil {
		log.Errorf("Failed to prepare database statement (%s). %s", query, err)
		respondError(s, m.ChannelID)
		return
	}
	_, err = stmt.Exec(m.GuildID, approverRole.ID)
	if err != nil {
		log.Errorf("Failed to execute database statement (%s) with guild %s and role %s. %s", query, m.GuildID, approverRole.ID, err)
		respondError(s, m.ChannelID)
		return
	}

	respond(s, m.ChannelID, "Configured approver role to "+approverRole.Mention())
}

// setPublicChannelCommand is the command handler to set the public channel for the guild.
func setPublicChannelCommand(s *discordgo.Session, m *discordgo.MessageCreate) {
	log.Debugf("Received setPublicChannel command from %s", m.Author.ID)
	responseMsg := ""
	if !isGuildOwner(s, m) {
		responseMsg = "You're not the guild owner, you can't do that!"
		_, err := s.ChannelMessageSend(m.ChannelID, responseMsg)
		if err != nil {
			log.Errorf("Failed to respond to setPublicChannel command. %s", err)
		}
		return
	} else {
		log.Debugf("Owner validation passed for author %s in guild %s", m.Author.ID, m.GuildID)
	}

	inputChannel := strings.Split(m.Content, " ")[1]
	log.Debugf("Setting public channel to %s for guild %s", inputChannel, m.GuildID)
	if isLink(inputChannel) {
		inputChannel = stripLink(inputChannel)
	} else {
		// Find channel by name
		channels, err := s.GuildChannels(m.GuildID)
		if err != nil {
			log.Errorf("Failed to get guild %s channels. %s", m.GuildID, err)
			respondError(s, m.ChannelID)
			return
		}
		for _, c := range channels {
			if c.Name == inputChannel {
				inputChannel = c.ID
				break
			}
		}
	}
	publicChannel, err := s.State.Channel(inputChannel)
	if err != nil {
		log.Errorf("Failed to get public channel %s in guild %s. %s", inputChannel, m.GuildID, err)
		respondError(s, m.ChannelID)
		return
	}

	query := "INSERT OR REPLACE INTO approval_pubchannel (guild_id, pubchannel) VALUES (?, ?)"
	stmt, err := DB.Prepare(query)
	if err != nil {
		log.Errorf("Failed to prepare database statement (%s). %s", query, err)
		respondError(s, m.ChannelID)
		return
	}
	_, err = stmt.Exec(m.GuildID, publicChannel.ID)
	if err != nil {
		log.Errorf("Failed to execute database statement (%s) with guild %s and channel %s. %s", query, m.GuildID, publicChannel.ID, err)
		respondError(s, m.ChannelID)
		return
	}

	_, err = s.ChannelMessageSend(m.ChannelID, "Configured public channel to "+publicChannel.Mention())
	if err != nil {
		log.Errorf("Failed to respond to setPublicChannel command. %s", err)
	}
}

// setApproverChannelCommand is the command handler to set the approver channel for the guild.
func setApproverChannelCommand(s *discordgo.Session, m *discordgo.MessageCreate) {
	log.Debugf("Received setApproverChannel command from %s", m.Author.ID)
	responseMsg := ""
	if !isGuildOwner(s, m) {
		responseMsg = "You're not the guild owner, you can't do that!"
		respond(s, m.ChannelID, responseMsg)
		return
	} else {
		log.Debugf("Owner validation passed for author %s in guild %s", m.Author.ID, m.GuildID)
	}

	inputChannel := strings.Split(m.Content, " ")[1]
	log.Debugf("Setting approver channel to %s for guild %s", inputChannel, m.GuildID)
	if isLink(inputChannel) {
		inputChannel = stripLink(inputChannel)
	} else {
		// Find channel by name
		channels, err := s.GuildChannels(m.GuildID)
		if err != nil {
			log.Errorf("Failed to get guild %s channels. %s", m.GuildID, err)
			respondError(s, m.ChannelID)
			return
		}
		for _, c := range channels {
			if c.Name == inputChannel {
				inputChannel = c.ID
				break
			}
		}
	}
	approvalChannel, err := s.State.Channel(inputChannel)
	if err != nil {
		log.Errorf("Failed to get approval channel %s in guild %s. %s", inputChannel, m.GuildID, err)
		respondError(s, m.ChannelID)
		return
	}

	query := "INSERT OR REPLACE INTO approval_channel (guild_id, channel) VALUES (?, ?)"
	stmt, err := DB.Prepare(query)
	if err != nil {
		log.Errorf("Failed to prepare database statement (%s). %s", query, err)
		respondError(s, m.ChannelID)
		return
	}
	_, err = stmt.Exec(m.GuildID, approvalChannel.ID)
	if err != nil {
		log.Errorf("Failed to execute database statement (%s) with guild %s and channel %s. %s", query, m.GuildID, approvalChannel.ID, err)
		respondError(s, m.ChannelID)
		return
	}

	respond(s, m.ChannelID, "Configured approval channel to "+approvalChannel.Mention())

}

// showConfigCommand is the command handler to show the current configuration for the guild.
func showConfigCommand(s *discordgo.Session, m *discordgo.MessageCreate) {
	pubrole, pubchannel, role, channel, err := getGuildConfig(m.GuildID)
	responseMsg := ""
	if err != nil {
		if err == sql.ErrNoRows {
			log.Warnf("Config not complete for guild %s", m.GuildID)
			responseMsg = "Configuration of this guild is incomplete. Use `*setPublicRole`, `*setPublicChannel`, `*setApproverRole` and `*setApproverChannel` to configure."
		} else {
			log.Errorf("Error querying config for guild %s. %s", m.GuildID, err)
			respondError(s, m.ChannelID)
			return
		}
	} else {
		log.Debugf("Config query completed for guild %s.", m.GuildID)
		pubRoleObj, err := s.State.Role(m.GuildID, pubrole)
		if err != nil {
			log.Errorf("Failed to get public role name (%s) for guild %s. %s", pubrole, m.GuildID, err)
			respondError(s, m.ChannelID)
			return
		}
		pubroleName := pubRoleObj.Name

		pubchannelObj, err := s.State.Channel(pubchannel)
		if err != nil {
			log.Errorf("Failed to get public channel name (%s) for guild %s. %s", pubchannel, m.GuildID, err)
			respondError(s, m.ChannelID)
			return
		}
		pubchannelName := pubchannelObj.Name

		channelObj, err := s.State.Channel(channel)
		if err != nil {
			log.Errorf("Failed to get approver channel name (%s) for guild %s. %s", channel, m.GuildID, err)
			respondError(s, m.ChannelID)
			return
		}
		channelName := channelObj.Name

		roleObj, err := s.State.Role(m.GuildID, role)
		if err != nil {
			log.Errorf("Failed to get approver role name (%s) for guild %s. %s", role, m.GuildID, err)
			respondError(s, m.ChannelID)
			return
		}
		roleName := roleObj.Name

		responseMsg = fmt.Sprintf("Current configuration:\n\nPublic role: %s\nPublic channel: %s\nApprover role: %s\nApprover channel: %s\n\nApproova, an open source discord bot by Alex.  https://github.com/alex4108/Approova", pubroleName, pubchannelName, roleName, channelName)
	}

	respond(s, m.ChannelID, responseMsg)
}

// pingCommand is the command handler to ping the bot.
func pingCommand(s *discordgo.Session, m *discordgo.MessageCreate) {
	now := time.Now()
	latency := ""
	if timestampFieldExists(m) {
		diff := m.Timestamp.Sub(now)
		latency = "(" + strconv.Itoa(int(diff.Milliseconds())) + " ms)"
	}
	respond(s, m.ChannelID, "Pong! "+latency)
}

// helpCommand is the command handler to show the help message.
func helpCommand(s *discordgo.Session, m *discordgo.MessageCreate) {
	messageContent := `Approova, an open source Discord Bot.

Available Commands:
	*help
	*ping
	*setApproverChannel
	*setApproverRole
	*setPublicChannel
	*setPublicRole

Proudly maintained by Alex https://github.com/alex4108/Approova
`

	respond(s, m.ChannelID, messageContent)
}

// respondError is a quick way to respond with an error message.
func respondError(s *discordgo.Session, channelID string) {
	respond(s, channelID, "An internal error occured.  Please raise a bug on the github repository for further investigation.")
}

func respond(s *discordgo.Session, channelID string, response string) {
	_, err := s.ChannelMessageSend(channelID, response)
	if err != nil {
		log.Errorf("Failed to respond to setApproverChannelCommand command. %s", err)
	}
}

func stripLink(channel string) string {
	channel = strings.Replace(channel, "<#", "", 1)
	channel = strings.Replace(channel, "<@&", "", 1)
	channel = strings.Replace(channel, "<@", "", 1)
	channel = strings.Replace(channel, ">", "", 1)
	return channel
}

func isLink(channel string) bool {
	return (strings.HasPrefix(channel, "<#") || strings.HasPrefix(channel, "<@")) && strings.HasSuffix(channel, ">")
}

func timestampFieldExists(obj *discordgo.MessageCreate) bool {
	metaValue := reflect.ValueOf(obj).Elem()
	field := metaValue.FieldByName("Timestamp")
	return field != (reflect.Value{})
}

func isGuildOwner(s *discordgo.Session, m *discordgo.MessageCreate) bool {
	guildId := m.GuildID
	userId := m.Author.ID
	log.Debugf("Checking if user %s is guild owner %s", guildId, userId)
	guild, err := s.State.Guild(guildId)
	if err != nil {
		log.Errorf("Error getting guild, %s", err)
		return false
	}
	return guild.OwnerID == userId
}
