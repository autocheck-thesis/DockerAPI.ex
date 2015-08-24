
all: deps
	@mix compile

deps:
	@mix deps.get

test:
	@mix test

doc:
	@MIX_ENV=docs mix deps.get
	@MIX_ENV=docs mix docs
