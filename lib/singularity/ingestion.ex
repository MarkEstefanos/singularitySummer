defmodule Singularity.Ingestion do
  @moduledoc """
  Ingestion pipeline — takes a file upload and processes it into a vault item
  with extracted metadata and text.
  """

  alias Singularity.Vault
  alias Singularity.Ingestion.{TextHandler, GenericHandler}

  @handlers [TextHandler, GenericHandler]

  @doc """
  Ingest a file into a user's collection.

  Accepts a map with:
    - path: path to the uploaded file
    - name: original filename
    - content_type: MIME type
    - collection_id: target collection
    - user_id: owning user
  """
  def ingest(%{path: path, name: name, content_type: content_type,
               collection_id: collection_id, user_id: user_id}) do
    handler = find_handler(content_type)

    with {:ok, extraction} <- handler.extract(path, content_type),
         storage_path <- store_file(path, user_id, name),
         {:ok, item} <- Vault.create_item(%{
           name: name,
           content_type: content_type,
           size_bytes: file_size(path),
           storage_path: storage_path,
           metadata: extraction.metadata,
           extracted_text: extraction.extracted_text,
           collection_id: collection_id,
           user_id: user_id
         }) do
      # TODO: Generate embedding from extracted_text asynchronously
      {:ok, item}
    end
  end

  defp find_handler(content_type) do
    Enum.find(@handlers, GenericHandler, & &1.can_handle?(content_type))
  end

  defp store_file(source_path, user_id, name) do
    # For MVP: copy to local storage directory
    dest_dir = Path.join(["priv", "uploads", to_string(user_id)])
    File.mkdir_p!(dest_dir)
    dest = Path.join(dest_dir, "#{System.unique_integer([:positive])}_#{name}")
    File.cp!(source_path, dest)
    dest
  end

  defp file_size(path) do
    case File.stat(path) do
      {:ok, %{size: size}} -> size
      _ -> nil
    end
  end
end
