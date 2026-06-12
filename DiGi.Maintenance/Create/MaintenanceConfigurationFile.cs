using DiGi.Core.Classes;
using DiGi.Maintenance.Classes;
using System.Reflection;

namespace DiGi.Maintenance
{
    public static partial class Create
    {
        /// <summary>
        /// Creates and initializes a <see cref="MaintenanceConfigurationFile"/> by loading settings from the default configuration file located in the application's execution directory.
        /// </summary>
        /// <returns>A new instance of <see cref="MaintenanceConfigurationFile"/> if successful; otherwise, <c>null</c> if the execution directory cannot be determined.</returns>
        public static MaintenanceConfigurationFile? MaintenanceConfigurationFile()
        {
            if (System.IO.Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location) is not string directory)
            {
                return null;
            }

            string path = System.IO.Path.Combine(directory, Constants.FileName.ConfigurationFile);

            ConfigurationFile? configurationFile = Core.Create.ConfigurationFile(path);
            configurationFile ??= new ConfigurationFile();

            return new MaintenanceConfigurationFile(configurationFile);
        }
    }
}