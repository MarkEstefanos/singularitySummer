defmodule Singularity.Ingestion.TextHandler do
  @moduledoc """
  Handler for plain text, markdown, and similar text formats.
  """

  @behaviour Singularity.Ingestion.Handler

  @text_types ~w(text/plain text/markdown text/csv text/html application/json)

  @impl true
  def can_handle?(content_type) do
    content_type in @text_types or String.starts_with?(content_type, "text/")
  end

  @impl true
  def extract(path, content_type) do
    case File.read(path) do
      {:ok, content} ->
        {:ok, %{
          metadata: %{
            "content_type" => content_type,
            "char_count" => String.length(content),
            "line_count" => length(String.split(content, "\n"))
          },
          extracted_text: content
        }}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
