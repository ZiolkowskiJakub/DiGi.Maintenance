using DiGi.GitHub.Classes;
using DiGi.Maintenance.Classes;

namespace DiGi.Maintenance.UI
{
    public static partial class Modify
    {
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