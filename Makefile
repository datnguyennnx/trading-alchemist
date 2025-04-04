SHELL := /bin/bash

.PHONY: setup db db.reset start stop migrations.run seed docker.up docker.down docker.build clean dev help

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

setup: ## Install dependencies and setup the project
	mix deps.get
	mix compile
	cd assets && npm install

db: ## Create and migrate database
	mix ecto.setup

db.reset: ## Drop and recreate database
	mix ecto.drop
	mix ecto.create
	mix ecto.migrate

db.migrate: ## Run migrations
	mix ecto.migrate

seed: ## Seed the database
	mix run priv/repo/seeds.exs

docker.up: ## Start Docker services
	@echo "Starting PostgreSQL with TimescaleDB..."
	docker-compose up -d db
	@echo "Waiting for PostgreSQL to be ready..."
	@sleep 5
	@echo "PostgreSQL is ready on port 5433"

docker.down: ## Stop Docker services
	@echo "Stopping all Docker services..."
	docker-compose down

docker.build: ## Build Docker images
	@echo "Building Docker images..."
	docker-compose build

clean: ## Clean compiled artifacts
	@echo "Cleaning compiled artifacts..."
	mix clean
	rm -rf _build

start: ## Start Phoenix server
	@echo "Starting Phoenix server..."
	mix phx.server

stop: ## Stop Phoenix server
	@echo "Stopping Phoenix server (if running)..."
	-pkill -f "mix phx.server"

dev: docker.up db.migrate start ## Full development environment

.DEFAULT_GOAL := help 