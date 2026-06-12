using DiGi.GitHub.Classes;
using DiGi.Maintenance.Classes;

namespace DiGi.Maintenance.UI
{
    public static partial class Modify
    {
        /// <summary>
        /// Synchronizes the specified solution with a GitHub repository using the provided configuration settings.
        /// </summary>
        /// <param name="gitHubConfigurationFile">The GitHub configuration file containing integration settings.</param>
        /// <param name="solution">The solution to be synchronized.</param>
        /// <param name="commitMessage">An optional commit message to include with the synchronization process.</param>
        /// <returns>True if the synchronization was successful; otherwise, false.</returns>
        public static bool Sync(this GitHubConfigurationFile? gitHubConfigurationFile, Solution solution, string? commitMessage = null)
        {
            if (gitHubConfigurationFile is null || solution == null)
            {
                return false;
            }

            if (solution.Path is not string path || string.IsNullOrWhiteSpace(path))
            {
                return false;
            }

            return GitHub.Modify.Sync(gitHubConfigurationFile, System.IO.Path.GetDirectoryName(path), solution.Version?.ToString(), commitMessage);
        }
    }
}