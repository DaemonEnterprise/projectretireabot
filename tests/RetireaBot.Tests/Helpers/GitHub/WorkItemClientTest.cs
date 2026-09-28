using Azure.Core;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Microsoft.RetireaBot.Helpers.Settings;
using Microsoft.RetireaBot.Models;
using Moq;

namespace Microsoft.RetireaBot.Tests.Helpers.GitHub
{
    public class WorkItemClientTest
    {
        [Theory]
        [InlineData(true)]
        [InlineData(false)]
        public async Task CreateBatchAsync_IncludeResourceId_ConfiguresIssueBody(bool includeResourceId)
        {
            IConfiguration config = new ConfigurationBuilder()
                .AddInMemoryCollection(new Dictionary<string, string?>
                {
                    [ConfigKeys.GitHub.PAT] = "test-token",
                    [ConfigKeys.GitHub.TargetRepository] = "owner/repo",
                    [ConfigKeys.GitHub.IncludeResourceId] = includeResourceId.ToString()
                })
                .Build();
            using ILoggerFactory loggerFactory = LoggerFactory.Create(builder => builder.AddDebug());
            var authModeService = new Microsoft.RetireaBot.Helpers.GitHub.AuthModeService(config);
            var credentialProvider = new Microsoft.RetireaBot.Helpers.GitHub.CredentialProvider(
                loggerFactory,
                Mock.Of<TokenCredential>(),
                authModeService,
                keyClient: null);
            var vendorSettings = new VendorSettingsProvider(
                config,
                [WorkItemBackend.GitHub],
                []);
            var sut = new Microsoft.RetireaBot.Helpers.GitHub.WorkItemClient(
                loggerFactory,
                credentialProvider,
                vendorSettings);
            var advisory = TestData.CreateAdvisory();

            var results = await sut.CreateBatchAsync(
                [advisory],
                "owner/repo",
                assignCopilot: false,
                whatIf: true);

            string body = Assert.Single(results).Item2.Body;
            if (includeResourceId)
            {
                Assert.Contains($"**Resource ID:** {advisory.Properties.ResourceMetadata.ResourceId}", body);
            }
            else
            {
                Assert.DoesNotContain("**Resource ID:**", body);
            }
        }
    }
}
