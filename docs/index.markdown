---
layout: page
title: Approova Docs
permalink: /
---

# Approova Docs

## 0. Concepts

### 0.1. Approvals/Approvers

1. Approver Channel: The channel where the Approver User will receive approval requests for newly joined guild members.
2. Approver Role: The role that the Approver User must have to approve new guild members.
3. Approval Requests: The message posted by the bot in the Approval Channel related to a new guild member.

### 0.2. Public

1. Public Channel: This is the channel where Approova will communicate with newly joined members.
2. Public Role: This is the role that newly joined members will be assigned to after their Approval Request has been
approved in the Approval Channel.

## 1. Setup

This section describes how to set up and configure Approova. You must be the creator of the Guild to carry out these
steps.

### 1.1. Join the Bot

Click [this link](https://discord.com/api/oauth2/authorize?client_id=743249218491121695&permissions=268635200&scope=bot)
and select the Guild you wish to join the bot to.

### 1.2. Configure the Bot

Once the bot is joined, run the following setup commands in any channel the bot can see your messages in. Commands are
case-sensitive.

#### 1.2.1. Set the Approval Channel

`*setApproverChannel #channel-name` OR `*setApprovalChannel channel-name`. Hashtags are optional.

#### 1.2.2. Set the Public Channel

`*setPublicChannel #channel-name` OR `*setApprovalChannel channel-name`. Hashtags are optional.

#### 1.2.3. Set the Approver Role

`*setApproverRole @role-name` OR `*setApproverRole role-name`. At-signs are optional.

#### 1.2.4. Set the Public Role

`*setPublicRole @role-name` OR `*setPublicRole role-name`. At-signs are optional.

## 2. Usage

This section describes how to use Approova. The bot must be configured for usage to be enabled.

### 2.1. New member join events

When a new member join event occurs, Approova will post two messages.

1. A message in the Public Channel communicating to the new user that they have been placed in queue.
2. A message in the Approval Channel communicating that the new user is pending approval.

### 2.2. Approving new members

To approve a new member, a user holding the Approver Role must click the Green Emoji check mark under the Approval. Note
that once approvals are processed, they cannot be revoked by the bot.

Once the emoji is clicked, Approova will communicate who processed the approval in the Approver Channel. The bot will
then grant the Public Role to the member related to the Approval Request.