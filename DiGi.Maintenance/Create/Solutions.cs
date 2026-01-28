using DiGi.Maintenance.Classes;
using System.Collections.Generic;

namespace DiGi.Maintenance
{
    public static partial class Create
    {
        public static List<Solution>? Solutions(string? directory)
        {
            if (string.IsNullOrEmpty(directory) || !System.IO.Directory.Exists(directory))
            {
                return null;
            }

            string[] paths = System.IO.Directory.GetFiles(directory, "*.sln");
            if (paths == null)
            {
                return null;
            }

            List<Solution> result = [];

            foreach (string path in paths)
            {
                Solution? solution = Solution(path);
                if (solution == null)
                {
                    continue;
                }

                result.Add(solution);
            }

            return result;
        }
    }
}