using DiGi.Core.Classes;
using DiGi.GitHub.Classes;
using System.Reflection;

namespace DiGi.Maintenance.UI
{
    public static partial class Create
    {
        /// <summary>
        /// Creates or loads a <see cref="GitHubConfigurationFile"/> instance from the executing assembly's directory.
        /// </summary>
        /// <returns>The loaded <see cref="GitHubConfigurationFile"/> instance if successful; otherwise, <c>null</c>.</returns>
        public static GitHubConfigurationFile? GitHubConfigurationFile()
        {
            if (System.IO.Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location) is not string directory)
            {
                return null;
            }

            string path = System.IO.Path.Combine(directory, GitHub.Constants.FileName.GitHubConfigurationFile);

            ConfigurationFile? configurationFile = Core.Create.ConfigurationFile(path);
            if (configurationFile is null)
            {
                return null;
            }

            return new GitHubConfigurationFile(configurationFile);
        }
    }
}