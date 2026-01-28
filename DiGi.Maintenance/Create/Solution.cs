using DiGi.Maintenance.Classes;
using System.Collections.Generic;
using System.Linq;
using System.Xml.Linq;

namespace DiGi.Maintenance
{
    public static partial class Create
    {
        public static Solution? Solution(string? path)
        {
            if (string.IsNullOrEmpty(path) || !System.IO.File.Exists(path))
            {
                return null;
            }

            string name = System.IO.Path.GetFileNameWithoutExtension(path);

            string? directory = System.IO.Path.GetDirectoryName(path);

            System.Version? version = null;

            string path_Properties = System.IO.Path.Combine(directory, "Directory.Build.props");
            if (System.IO.File.Exists(path_Properties))
            {
                // Read file text (trim whitespace to handle BOM/leading whitespace)
                string xmlText = System.IO.File.ReadAllText(path_Properties).Trim();

                // Parse it as XML
                XDocument xDocument = XDocument.Parse(xmlText);

                //XDocument xDocument = XDocument.Parse(path);

                Dictionary<string, string>? dictionary = xDocument?.Descendants("PropertyGroup").Elements().ToDictionary(e => e.Name.LocalName, e => e.Value);
                if (dictionary != null)
                {
                    int major = -1;
                    int minor = -1;
                    int build = -1;

                    if (!dictionary.TryGetValue("Major", out string? value) || !int.TryParse(value, out major))
                    {
                        major = -1;
                    }

                    if (!dictionary.TryGetValue("Minor", out value) || !int.TryParse(value, out minor))
                    {
                        minor = -1;
                    }

                    if (!dictionary.TryGetValue("Build", out value) || !int.TryParse(value, out build))
                    {
                        build = -1;
                    }

                    version = new System.Version(major, minor, build);
                }
            }

            return new Solution(path!, version);
        }
    }
}