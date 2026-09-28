using System.Net;
using System.Text.Json;
using Microsoft.RetireaBot.Models.Azure;
using Moq;
using Moq.Protected;

namespace Microsoft.RetireaBot.Tests.Helpers.Azure
{
    public class ManagementClientTest
    {
        private sealed class QueryItem
        {
            public string Name { get; set; } = string.Empty;
        }

        private static Microsoft.RetireaBot.Helpers.Azure.ManagementClient BuildClient(Mock<HttpMessageHandler> handler)
        {
            var httpClient = new HttpClient(handler.Object)
            {
                BaseAddress = new Uri("https://management.azure.com/")
            };
            return new Microsoft.RetireaBot.Helpers.Azure.ManagementClient(httpClient);
        }

        private static void SetupResponse(Mock<HttpMessageHandler> handler, HttpStatusCode status, string content)
        {
            handler.Protected()
                .Setup<Task<HttpResponseMessage>>("SendAsync", ItExpr.IsAny<HttpRequestMessage>(), ItExpr.IsAny<CancellationToken>())
                .ReturnsAsync(new HttpResponseMessage
                {
                    StatusCode = status,
                    Content = new StringContent(content, System.Text.Encoding.UTF8, "application/json")
                });
        }

        [Fact]
        public async Task GetSubscriptionsAsync_ReturnsSubscriptions()
        {
            var handler = new Mock<HttpMessageHandler>();
            SetupResponse(handler, HttpStatusCode.OK,
                """{ "value": [{ "subscriptionId": "sub-123" }] }""");

            var client = BuildClient(handler);
            var subs = await client.GetSubscriptionsAsync();

            Assert.Single(subs);
            Assert.Equal("sub-123", subs[0]);
        }


        [Fact]
        public async Task GetSubscriptionsAsync_MultipleSubscriptions_ReturnsAll()
        {
            var handler = new Mock<HttpMessageHandler>();
            SetupResponse(handler, HttpStatusCode.OK,
                """{ "value": [{ "subscriptionId": "sub-1" }, { "subscriptionId": "sub-2" }] }""");

            var client = BuildClient(handler);
            var subs = await client.GetSubscriptionsAsync();

            Assert.Equal(2, subs.Length);
        }

        [Fact]
        public async Task GetSubscriptionsAsync_ServerError_ThrowsHttpRequestException()
        {
            var handler = new Mock<HttpMessageHandler>();
            SetupResponse(handler, HttpStatusCode.InternalServerError, "");

            var client = BuildClient(handler);

            await Assert.ThrowsAsync<HttpRequestException>(() => client.GetSubscriptionsAsync());
        }

        [Fact]
        public async Task RunQueryAsync_NullResponse_ThrowsInvalidOperation()
        {
            var handler = new Mock<HttpMessageHandler>();
            SetupResponse(handler, HttpStatusCode.OK, "null");

            var client = BuildClient(handler);

            await Assert.ThrowsAsync<InvalidOperationException>(
                () => client.RunQueryAsync<RetirementData>("sub-1", "some query"));
        }

        [Fact]
        public async Task RunQueryAsync_MultiplePages_ReturnsCombinedResultsAndUsesSkipToken()
        {
            var responses = new Queue<HttpResponseMessage>(
            [
                new HttpResponseMessage
                {
                    StatusCode = HttpStatusCode.OK,
                    Content = new StringContent(
                        """{"count":2,"data":[{"name":"one"},{"name":"two"}],"$skipToken":"next-page","resultTruncated":"true","totalRecords":3}""",
                        System.Text.Encoding.UTF8,
                        "application/json")
                },
                new HttpResponseMessage
                {
                    StatusCode = HttpStatusCode.OK,
                    Content = new StringContent(
                        """{"count":1,"data":[{"name":"three"}],"resultTruncated":"false","totalRecords":3}""",
                        System.Text.Encoding.UTF8,
                        "application/json")
                }
            ]);
            var requestBodies = new List<string>();
            var handler = new Mock<HttpMessageHandler>();
            handler.Protected()
                .Setup<Task<HttpResponseMessage>>(
                    "SendAsync",
                    ItExpr.IsAny<HttpRequestMessage>(),
                    ItExpr.IsAny<CancellationToken>())
                .Callback<HttpRequestMessage, CancellationToken>((request, _) =>
                    requestBodies.Add(request.Content!.ReadAsStringAsync().GetAwaiter().GetResult()))
                .ReturnsAsync(() => responses.Dequeue());

            var client = BuildClient(handler);

            QueryResult<QueryItem> result = await client.RunQueryAsync<QueryItem>("sub-1", "resources");

            Assert.Equal(3, result.Length);
            Assert.Equal(3, result.TotalRecords);
            Assert.Equal(["one", "two", "three"], result.Data.Select(item => item.Name));
            Assert.Equal(2, requestBodies.Count);

            using JsonDocument firstRequest = JsonDocument.Parse(requestBodies[0]);
            Assert.False(firstRequest.RootElement.TryGetProperty("options", out _));

            using JsonDocument secondRequest = JsonDocument.Parse(requestBodies[1]);
            Assert.True(
                secondRequest.RootElement.TryGetProperty("options", out JsonElement options),
                requestBodies[1]);
            Assert.True(options.TryGetProperty("$skipToken", out JsonElement token), requestBodies[1]);
            Assert.Equal("next-page", token.GetString());
        }
    }
}