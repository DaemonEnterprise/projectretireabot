using Microsoft.RetireaBot.Helpers;

namespace Microsoft.RetireaBot.Tests.Helpers
{
    public class WorkItemClientCommonTests
    {
        [Fact]
        public void GenerateAdvisoryLabel_LabelsDifferOnlyAfterMaximumLength_ReturnsDistinctLabels()
        {
            string sharedPrefix = new('a', 50);

            string first = WorkItemClientCommon.GenerateAdvisoryLabel(
                "advisor-",
                $"{sharedPrefix}-first",
                50);
            string second = WorkItemClientCommon.GenerateAdvisoryLabel(
                "advisor-",
                $"{sharedPrefix}-second",
                50);

            Assert.NotEqual(first, second);
            Assert.Equal(50, first.Length);
            Assert.Equal(50, second.Length);
        }

        [Fact]
        public void GenerateAdvisoryLabel_LabelFitsMaximumLength_ReturnsUnchangedLabel()
        {
            string result = WorkItemClientCommon.GenerateAdvisoryLabel(
                "advisor-",
                "advisory-1",
                50);

            Assert.Equal("advisor-advisory-1", result);
        }

        [Fact]
        public void GenerateAdvisoryLabel_OversizedLabelWithDifferentCasing_ReturnsEquivalentLabel()
        {
            string advisoryName = new('a', 50);

            string lowerCase = WorkItemClientCommon.GenerateAdvisoryLabel(
                "advisor-",
                advisoryName,
                50);
            string upperCase = WorkItemClientCommon.GenerateAdvisoryLabel(
                "ADVISOR-",
                advisoryName.ToUpperInvariant(),
                50);

            Assert.Equal(lowerCase, upperCase, ignoreCase: true);
        }

        [Fact]
        public void HasAdvisoryLabel_MatchingLabelIsNotFirst_ReturnsTrue()
        {
            string[] labels =
            [
                "advisor-type-retirement",
                "high",
                "advisor-advisory-1"
            ];

            bool result = WorkItemClientCommon.HasAdvisoryLabel(
                labels,
                "advisor-",
                "advisory-1",
                50);

            Assert.True(result);
        }

        [Fact]
        public void HasAdvisoryLabel_LabelHasDifferentCasing_ReturnsTrue()
        {
            string[] labels = ["ADVISOR-ADVISORY-1"];

            bool result = WorkItemClientCommon.HasAdvisoryLabel(
                labels,
                "advisor-",
                "advisory-1",
                50);

            Assert.True(result);
        }

        [Fact]
        public void HasAdvisoryLabel_OnlyAnotherPrefixedLabelExists_ReturnsFalse()
        {
            string[] labels = ["advisor-type-retirement"];

            bool result = WorkItemClientCommon.HasAdvisoryLabel(
                labels,
                "advisor-",
                "advisory-1",
                50);

            Assert.False(result);
        }
    }
}
