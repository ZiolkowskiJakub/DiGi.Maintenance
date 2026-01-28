using DiGi.Core.Classes;
using DiGi.Maintenance.Classes;
using System.Reflection;

namespace DiGi.Maintenance
{
    public static partial class Create
    {
        public static MaintenanceConfigurationFile? MaintenanceConfigurationFile()
        {
            if (System.IO.Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location) is not string directory)
            {
                return null;
            }

            string path = System.IO.Path.Combine(directory, Constans.FileName.ConfigurationFile);

            ConfigurationFile? configurationFile = Core.Create.ConfigurationFile(path);
            configurationFile ??= new ConfigurationFile();

            return new MaintenanceConfigurationFile(configurationFile);
        }
    }
}