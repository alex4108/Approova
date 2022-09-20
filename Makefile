PHONY: .build

ifndef APPROOVA_TAG
override APPROOVA_TAG = approova
endif

build:
	go build -o ./bin/approova

docker: build
	docker build -t $(APPROOVA_TAG) .