#!/usr/bin/env bash

export MIX_ENV=prod
SECRET=$(mix phx.gen.secret)

echo "Generated secret $SECRET"

mix deps.get --only prod

mix compile

mix assets.deploy

mix phx.gen.release

mix release

tar -vcJf 

export MIX_ENV=
