PHONY: .build

ifndef GITHUB_SHA
override GITHUB_SHA = approova
endif

build:
	go build -o ./bin/approova

docker: build
	docker build -t $(GITHUB_SHA) .