defmodule Flog.Repo do
  use Ecto.Repo,
    otp_app: :flog,
    adapter: Ecto.Adapters.Postgres
end
