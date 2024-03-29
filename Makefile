PHONY: .build .docker .docker-release .test

ifndef APPROOVA_TAG
override APPROOVA_TAG = approova
endif

build:
	export CGO_ENABLED=1
	go install github.com/mattn/go-sqlite3 && go build -o ../bin/approova

docker: build
	docker build -t $(APPROOVA_TAG) .

docker-release: build
	docker buildx build --platform linux/amd64 -t alex4108/approova:$(APPROOVA_TAG) --push .

test: docker
	docker run --rm -e CI=true $(APPROOVA_TAG)