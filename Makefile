PHONY: .build

ifndef APPROOVA_TAG
override APPROOVA_TAG = approova
endif

build:
	go build -o ./bin/approova

docker: build
	docker build -t $(APPROOVA_TAG) .

docker-release: build
	docker buildx build --platform linux/amd64,linux/arm64,linux/arm/v7 -t alex4108/approova:$(APPROOVA_TAG) --push .