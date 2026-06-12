using DiGi.Core.Classes;
using System.Text.Json.Nodes;

namespace DiGi.Maintenance.Classes
{
    /// <summary>
    /// Represents the configuration settings specifically for maintenance operations, extending the base configuration file functionality.
    /// </summary>
    public class MaintenanceConfigurationFile : ConfigurationFile
    {
        /// <summary>
        /// Initializes a new instance of the <see cref="MaintenanceConfigurationFile"/> class copying settings from the source configuration file.
        /// </summary>
        /// <param name="configurationFile">The source configuration file to copy settings from.</param>
        public MaintenanceConfigurationFile(ConfigurationFile? configurationFile)
            : base(configurationFile)
        {
        }

        /// <summary>
        /// Initializes a new instance of the <see cref="MaintenanceConfigurationFile"/> class with the specified JSON object containing the configuration settings.
        /// </summary>
        /// <param name="jsonObject">The JSON object containing the configuration settings.</param>
        public MaintenanceConfigurationFile(JsonObject? jsonObject)
            : base(jsonObject)
        {
        }
    }
}