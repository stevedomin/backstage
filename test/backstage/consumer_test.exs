defmodule Backstage.ConsumerTest do
  use Backstage.IntegrationCase, async: true

  alias Backstage.Consumer
  alias Backstage.Producer

  test "" do
    {:ok, producer} = Producer.start_link()
    {:ok, _consumer} = Consumer.start_link()
  end
end
