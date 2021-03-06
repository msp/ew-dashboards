defmodule Core.Data.Query do

  @moduledoc """

  This module contains the base CRUD query functionality for any schema. The
  private functions, `create/2` and `update/3` are overridable so that the
  modules implementing them can keep the same workflow of `upsert/2` without
  rewriting the function.

  """

  @callback all(repo :: Atom) :: List.t
  @callback get(id :: Binary, repo :: Atom) :: Map.t | nil
  @callback upsert(map :: Map, repo :: Atom) :: {:ok, Map.t} | {:error, %Ecto.Changeset{}}
  @callback delete(id :: Binary, repo :: Atom) :: {:ok, Map.t} | {:error, %Ecto.Changeset{}}

  defmacro __using__(opts \\ []) do
    schema = opts[:schema] || __CALLER__.module
    quote do
      alias Core.Repo
      alias unquote(schema)

      @type t :: %unquote(schema){}
      @behaviour Core.Data.Query

      def all(repo \\ Repo) do
        unquote(schema)
        |> repo.all()
      end

      def get(id, repo \\ Repo)
      def get(id, repo) when is_binary(id) do
        repo.get_by(unquote(schema), %{id: id})
      end
      def get(_id, _repo), do: nil

      def upsert(params, repo \\ Repo) do
        with %unquote(schema){} = model <- get(params["id"], repo),
             {:ok, %unquote(schema){}} = result <- update(model, params, repo) do
          result
        else
          nil ->
            create(params, repo)
          {:error, %Ecto.Changeset{}} = changeset_error ->
            changeset_error
          error ->
            error
        end
      end

      def delete(id, repo \\ Repo) when is_binary(id) do
        %{
          "id" => id,
          "deleted" => true,
          "deleted_at" => DateTime.utc_now()
        } |> upsert(repo)
      end

      defp update(%unquote(schema){} = author, params, repo) do
        author
        |> unquote(schema).changeset(params)
        |> repo.update()
      end
      defoverridable [update: 3]

      defp create(params, repo) do
        %unquote(schema){}
        |> unquote(schema).changeset(params)
        |> repo.insert()
      end
      defoverridable [create: 2]

    end
  end
end
