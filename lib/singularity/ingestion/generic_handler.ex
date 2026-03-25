defmodule Singularity.Ingestion.GenericHandler do
  @moduledoc """
  Fallback handler for any file type. Stores the file with basic metadata
  but no text extraction.
  """

  @behaviour Singularity.Ingestion.Handler

  @impl true
  def can_handle?(_content_type), do: true

  @impl true
  def extract(path, content_type) do
    case File.stat(path) do
      {:ok, stat} ->
        {:ok, %{
          metadata: %{
            "content_type" => content_type,
            "size_bytes" => stat.size
          },
          extracted_text: nil
        }}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
