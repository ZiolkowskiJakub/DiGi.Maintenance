using DiGi.Core.Classes;
using DiGi.GitHub.Classes;
using System.Reflection;

namespace DiGi.Maintenance.UI
{
    public static partial class Create
    {
        public static GitHubConfigurationFile? GitHubConfigurationFile()
        {
            if (System.IO.Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location) is not string directory)
            {
                return null;
            }

            string path = System.IO.Path.Combine(directory, GitHub.Constans.FileName.GitHubConfigurationFile);

            ConfigurationFile? configurationFile = Core.Create.ConfigurationFile(path);
            if (configurationFile is null)
            {
                return null;
            }

            return new GitHubConfigurationFile(configurationFile);
        }
    }
}
