defmodule SPARQL.Client.QueryTest do
  use ExUnit.Case # In case test behaves unstable: , async: false

  alias SPARQL.Query


  @example_endpoint "http://example.org/sparql"

  @example_select_query "SELECT * WHERE { ?s ?p ?o }"

  @success_json_result """
    {
      "head": {
        "vars": [ "s" , "p" , "o" ]
      },
      "results": {
        "bindings": [
          {
            "s": { "type": "uri" , "value": "http://example.org/s1" } ,
            "p": { "type": "uri" , "value": "http://example.org/p1" } ,
            "o": { "type": "uri" , "value": "http://example.org/o1" }
          }
        ]
      }
    }
    """

  @success_xml_result """
    <sparql xmlns="http://www.w3.org/2005/sparql-results#" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.w3.org/2001/sw/DataAccess/rf1/result2.xsd">
      <head>
        <variable name="s"/>
        <variable name="p"/>
        <variable name="o"/>
      </head>
      <results>
        <result>
          <binding name="s">
            <uri>http://example.org/s1</uri>
          </binding>
          <binding name="p">
            <uri>http://example.org/p1</uri>
          </binding>
          <binding name="o">
            <uri>http://example.org/o1</uri>
          </binding>
        </result>
      </results>
    </sparql>
    """

  @success_tsv_result """
    ?s	?p	?o
    <http://example.org/s1>	<http://example.org/p1>	<http://example.org/o1>
    """

  @success_csv_result """
    s,p,o
    http://example.org/s1,http://example.org/p1,http://example.org/o1
    """

  @success_result @success_json_result |> Query.Result.JSON.decode() |> elem(1)

  @default_select_accept_header SPARQL.Client.default_accept_header(:select)
  @default_ask_accept_header SPARQL.Client.default_accept_header(:ask)


  describe "query request methods" do
    @success_response %Tesla.Env{
      status: 200,
      body: @success_json_result,
      headers: %{"content-type" => Query.Result.JSON.media_type}
    }

    test "via GET" do
      url = @example_endpoint <> "?" <> URI.encode_query(%{query: @example_select_query})
      Tesla.Mock.mock fn %{method: :get, url: ^url} -> @success_response end

      assert SPARQL.Client.query(@example_select_query, @example_endpoint,
              request_method: :get, protocol_version: "1.1") ==
                {:ok, @success_result}
    end

    test "via URL-encoded POST" do
      body = URI.encode_query(%{query: @example_select_query})
      Tesla.Mock.mock fn
        %{method: :post, url: @example_endpoint, body: ^body,
            headers: %{"content-type" => "application/x-www-form-urlencoded"}} ->
          @success_response
      end

      assert SPARQL.Client.query(@example_select_query, @example_endpoint,
              request_method: :post, protocol_version: "1.0") ==
                {:ok, @success_result}
    end

    test "via POST directly" do
      Tesla.Mock.mock fn
        %{method: :post, url: @example_endpoint, body: @example_select_query,
            headers: %{"content-type" => "application/sparql-query"}} ->
          @success_response
      end

      assert SPARQL.Client.query(@example_select_query, @example_endpoint,
              request_method: :post, protocol_version: "1.1") ==
                {:ok, @success_result}
    end

    test "default is via URL-encoded POST" do
      body = URI.encode_query(%{query: @example_select_query})
      Tesla.Mock.mock fn
        %{method: :post, url: @example_endpoint, body: ^body} ->
          @success_response
      end

      assert SPARQL.Client.query(@example_select_query, @example_endpoint) ==
              {:ok, @success_result}
    end

    test "invalid request forms" do
      assert SPARQL.Client.query(@example_select_query, @example_endpoint,
              request_method: :unknown_method, protocol_version: "1.1") ==
                {:error, "unknown request method: :unknown_method with SPARQL protocol version 1.1"}

      assert SPARQL.Client.query(@example_select_query, @example_endpoint,
              request_method: :post, protocol_version: "1.23") ==
                {:error, "unknown request method: :post with SPARQL protocol version 1.23"}

      assert SPARQL.Client.query(@example_select_query, @example_endpoint,
              request_method: :get, protocol_version: "1.0") ==
                {:error, "unknown request method: :get with SPARQL protocol version 1.0"}
    end
  end


  describe "SELECT response evaluation" do
    setup do
      {:ok, body: URI.encode_query(%{query: @example_select_query})}
    end

    test "with JSON result", %{body: body} do
      Tesla.Mock.mock fn
        %{method: :post, url: @example_endpoint, body: ^body,
            headers: %{"accept" => "application/sparql-results+json"}} ->
          %Tesla.Env{
                status: 200,
                body: @success_json_result,
                headers: %{"content-type" => "application/sparql-results+json"}
              }
      end

      assert SPARQL.Client.query(@example_select_query, @example_endpoint, result_format: :json) ==
              {:ok, @success_result}
    end

    test "with XML result", %{body: body} do
      Tesla.Mock.mock fn
        %{method: :post, url: @example_endpoint, body: ^body,
            headers: %{"accept" => "application/sparql-results+xml"}} ->
          %Tesla.Env{
                status: 200,
                body: @success_xml_result,
                headers: %{"content-type" => "application/sparql-results+xml"}
              }
      end

      assert SPARQL.Client.query(@example_select_query, @example_endpoint, result_format: :xml) ==
              {:ok, @success_result}
    end

    test "with TSV result", %{body: body} do
      Tesla.Mock.mock fn
        %{method: :post, url: @example_endpoint, body: ^body,
            headers: %{"accept" => "text/tab-separated-values"}} ->
          %Tesla.Env{
                status: 200,
                body: @success_tsv_result,
                headers: %{"content-type" => "text/tab-separated-values"}
              }
      end

      assert SPARQL.Client.query(@example_select_query, @example_endpoint, result_format: :tsv) ==
              {:ok, @success_result}
    end

    test "with CSV result", %{body: body} do
      Tesla.Mock.mock fn
        %{method: :post, url: @example_endpoint, body: ^body,
            headers: %{"accept" => "text/csv"}} ->
          %Tesla.Env{
                status: 200,
                body: @success_csv_result,
                headers: %{"content-type" => "text/csv"}
              }
      end

      assert SPARQL.Client.query(@example_select_query, @example_endpoint, result_format: :csv) ==
               Query.Result.CSV.decode(@success_csv_result)
    end

    test "with default accept header and best accepted content-type returned (JSON)", %{body: body} do
      Tesla.Mock.mock fn
        %{method: :post, url: @example_endpoint, body: ^body,
            headers: %{"accept" => @default_select_accept_header}} ->
          %Tesla.Env{
                status: 200,
                body: @success_json_result,
                headers: %{"content-type" => Query.Result.JSON.media_type}
              }
      end

      assert SPARQL.Client.query(@example_select_query, @example_endpoint) ==
              {:ok, @success_result}
    end

    test "with default accept header and worst accepted content-type returned (CSV)", %{body: body} do
      Tesla.Mock.mock fn
        %{method: :post, url: @example_endpoint, body: ^body,
            headers: %{"accept" => @default_select_accept_header}} ->
          %Tesla.Env{
                status: 200,
                body: @success_csv_result,
                headers: %{"content-type" => Query.Result.CSV.media_type}
              }
      end

      assert SPARQL.Client.query(@example_select_query, @example_endpoint) ==
               Query.Result.CSV.decode(@success_csv_result)
    end

    test "different content-type than the accepted", %{body: body} do
      Tesla.Mock.mock fn
        %{method: :post, url: @example_endpoint, body: ^body,
            headers: %{"accept" => "text/tab-separated-values"}} ->
          %Tesla.Env{
                status: 200,
                body: @success_json_result,
                headers: %{"content-type" => "application/sparql-results+json"}
              }
      end

      assert SPARQL.Client.query(@example_select_query, @example_endpoint, result_format: :tsv) ==
              {:ok, @success_result}
    end


    test "custom accept header", %{body: body} do
      Tesla.Mock.mock fn
        %{method: :post, url: @example_endpoint, body: ^body,
            headers: %{"accept" => "text/tab-separated-values"}} ->
          %Tesla.Env{
                status: 200,
                body: @success_tsv_result,
                headers: %{"content-type" => "text/tab-separated-values"}
              }
      end

      assert SPARQL.Client.query(@example_select_query, @example_endpoint,
                headers: %{"Accept" => "text/tab-separated-values"}) ==
              {:ok, @success_result}
    end

    test "unsupported content-type response and no result_format set", %{body: body} do
      Tesla.Mock.mock fn
        %{method: :post, url: @example_endpoint, body: ^body} ->
          %Tesla.Env{
                status: 200,
                body: "<html><body>HTML content</body></html>",
                headers: %{"content-type" => "text/html"}
              }
      end

      assert SPARQL.Client.query(@example_select_query, @example_endpoint) ==
              {:error, ~s[unsupported result format: "text/html"]}
    end

    test "unsupported content-type response is tried to be interpreted as result_format", %{body: body} do
      Tesla.Mock.mock fn
        %{method: :post, url: @example_endpoint, body: ^body} ->
          %Tesla.Env{
                status: 200,
                body: "<html><body>HTML content</body></html>",
                headers: %{"content-type" => "text/html"}
              }
      end

      assert SPARQL.Client.query(@example_select_query, @example_endpoint, result_format: :tsv) ==
              {:error, "invalid header variable: '<html><body>HTML content</body></html>'"}
    end
  end


  @example_ask_query "ASK WHERE { <http://example.org/Foo> a <http://example.org/Bar> }"

  @ask_success_json_result """
    {
      "head" : { } ,
      "boolean" : true
    }
    """

  @ask_success_xml_result """
    <sparql xmlns="http://www.w3.org/2005/sparql-results#" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.w3.org/2001/sw/DataAccess/rf1/result2.xsd">
      <boolean>true</boolean>
    </sparql>
    """

  @ask_success_result @ask_success_json_result |> Query.Result.JSON.decode() |> elem(1)

  describe "ASK response evaluation" do

    setup do
      {:ok, body: URI.encode_query(%{query: @example_ask_query})}
    end

    test "with JSON result", %{body: body} do
      Tesla.Mock.mock fn
        %{method: :post, url: @example_endpoint, body: ^body,
            headers: %{"accept" => "application/sparql-results+json"}} ->
          %Tesla.Env{
                status: 200,
                body: @ask_success_json_result,
                headers: %{"content-type" => "application/sparql-results+json"}
              }
      end

      assert SPARQL.Client.query(@example_ask_query, @example_endpoint, result_format: :json) ==
              {:ok, @ask_success_result}
    end

    test "with XML result", %{body: body} do
      Tesla.Mock.mock fn
        %{method: :post, url: @example_endpoint, body: ^body,
            headers: %{"accept" => "application/sparql-results+xml"}} ->
          %Tesla.Env{
                status: 200,
                body: @ask_success_xml_result,
                headers: %{"content-type" => "application/sparql-results+xml"}
              }
      end

      assert SPARQL.Client.query(@example_ask_query, @example_endpoint, result_format: :xml) ==
              {:ok, @ask_success_result}
    end

    test "with default accept header and best accepted content-type returned (JSON)", %{body: body} do
      Tesla.Mock.mock fn
        %{method: :post, url: @example_endpoint, body: ^body,
            headers: %{"accept" => @default_ask_accept_header}} ->
          %Tesla.Env{
                status: 200,
                body: @ask_success_json_result,
                headers: %{"content-type" => Query.Result.JSON.media_type}
              }
      end

      assert SPARQL.Client.query(@example_ask_query, @example_endpoint) ==
              {:ok, @ask_success_result}
    end

    test "unsupported content-type response and no result_format set", %{body: body} do
      Tesla.Mock.mock fn
        %{method: :post, url: @example_endpoint, body: ^body} ->
          %Tesla.Env{
                status: 200,
                body: "bool\ntrue",
                headers: %{"content-type" => "text/csv"}
              }
      end

      assert SPARQL.Client.query(@example_ask_query, @example_endpoint) ==
              {:error, ~s[unsupported result format for ask query: "text/csv"]}
    end

    test "unsupported content-type response is tried to be interpreted as result_format", %{body: body} do
      Tesla.Mock.mock fn
        %{method: :post, url: @example_endpoint, body: ^body} ->
          %Tesla.Env{
                status: 200,
                body: "<html><body>HTML content</body></html>",
                headers: %{"content-type" => "text/html"}
              }
      end

      assert SPARQL.Client.query(@example_ask_query, @example_endpoint, result_format: :json) ==
              {:error, %Jason.DecodeError{data: "<html><body>HTML content</body></html>", position: 0, token: nil}}
    end
  end

end