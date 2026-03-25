defmodule Singularity.Ingestion.Handler do
  @moduledoc """
  Behaviour for type-specific ingestion handlers.
  Each handler knows how to extract metadata and text from a specific content type.
  """

  @callback can_handle?(content_type :: String.t()) :: boolean()
  @callback extract(path :: String.t(), content_type :: String.t()) ::
              {:ok, %{metadata: map(), extracted_text: String.t() | nil}} | {:error, term()}
end
