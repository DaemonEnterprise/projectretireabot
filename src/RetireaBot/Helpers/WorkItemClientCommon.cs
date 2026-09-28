using Microsoft.RetireaBot.Models.Azure;
using System.Security.Cryptography;
using System.Text;

namespace Microsoft.RetireaBot.Helpers
{
    public class WorkItemClientCommon
    {
        public static string GenerateAdvisoryLabel(string prefix, string advisoryName, int maxLength)
        {
            var label = $"{prefix}{advisoryName}";
            if (label.Length <= maxLength)
            {
                return label;
            }

            const int hashLength = 12;
            string hash = Convert.ToHexString(
                SHA256.HashData(Encoding.UTF8.GetBytes(label.ToUpperInvariant())))
                .ToLowerInvariant()[..hashLength];

            if (maxLength <= hashLength)
            {
                return hash[..maxLength];
            }

            int readableLength = maxLength - hashLength - 1;
            return $"{label[..readableLength]}-{hash}";
        }

        public static bool HasAdvisoryLabel(IEnumerable<string> labels, string prefix, string advisoryName, int maxLength)
        {
            string advisoryLabel = GenerateAdvisoryLabel(prefix, advisoryName, maxLength);
            return labels.Any(label => label.Equals(advisoryLabel, StringComparison.OrdinalIgnoreCase));
        }

        public static string GenerateWorkItemTitle(Advisory advisory)
        {
            return $"{advisory.Properties.ShortDescription.Problem} - {advisory.Properties.ImpactedValue}";
        }
    }
}
