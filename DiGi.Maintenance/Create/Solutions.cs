using DiGi.Maintenance.Classes;
using System.Collections.Generic;

namespace DiGi.Maintenance
{
    public static partial class Create
    {
        /// <summary>
        /// Retrieves a list of solution files from the specified directory.
        /// </summary>
        /// <param name="directory">The path to the directory to search for .sln files.</param>
        /// <returns>A list of <see cref="Solution"/> objects found in the directory, or null if the directory is invalid or does not exist.</returns>
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