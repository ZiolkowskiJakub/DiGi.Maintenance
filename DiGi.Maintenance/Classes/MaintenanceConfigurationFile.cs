using DiGi.Core.Classes;
using System.Text.Json.Nodes;

namespace DiGi.Maintenance.Classes
{
    public class MaintenanceConfigurationFile : ConfigurationFile
    {
        public MaintenanceConfigurationFile(ConfigurationFile? configurationFile)
            :base(configurationFile)
        {

        }

        public MaintenanceConfigurationFile(JsonObject? jsonObject)
            : base(jsonObject)
        {

        }
    }
}

