using System;

namespace DiGi.Maintenance.Classes
{
    public class Solution
    {
        public string? Path { get; }

        public Version? Version { get; set; }

        public Solution(string? path, Version? version)
        {
            Path = path;
            Version = version;
        }

        public string? GetName()
        {
            if (string.IsNullOrWhiteSpace(Path))
            {
                return null;
            }

            return System.IO.Path.GetFileNameWithoutExtension(Path);
        }

        public string? GetDirectory()
        {
            if (string.IsNullOrWhiteSpace(Path))
            {
                return null;
            }

            return System.IO.Path.GetDirectoryName(Path);
        }
    }
}