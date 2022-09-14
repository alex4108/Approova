PHONY: .build

build:
	go build -o ./bin/approova

docker: build
	docker build -t approova .