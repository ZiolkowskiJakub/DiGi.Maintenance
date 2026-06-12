using System.Collections.Generic;
using System.IO;

namespace DiGi.Maintenance
{
    public static partial class Modify
    {
        /// <summary>
        /// Recursively removes empty directories within the specified root directory.
        /// </summary>
        /// <param name="directory">The path to the root directory to clean.</param>
        /// <returns>A <see cref="HashSet{T}"/> containing the paths of the deleted directories, or <c>null</c> if the input directory is invalid or no empty directories were found.</returns>
        public static HashSet<string>? CleanDirectories(this string directory)
        {
            if (string.IsNullOrWhiteSpace(directory) || !Directory.Exists(directory))
            {
                return null;
            }

            string[] directories = Directory.GetDirectories(directory, "*", SearchOption.AllDirectories);
            if (directories == null || directories.Length == 0)
            {
                return null;
            }

            HashSet<string> result = [];
            int count = -1;

            while (result.Count != count)
            {
                count = result.Count;

                for (int i = directories.Length - 1; i >= 0; i--)
                {
                    string directory_Temp = directories[i];

                    if (string.IsNullOrWhiteSpace(directory_Temp) || !Directory.Exists(directories[i]))
                    {
                        continue;
                    }

                    DirectoryInfo directoryInfo = new(directory_Temp);

                    DirectoryInfo directoryInfo_Parent = Directory.GetParent(directory_Temp);

                    if (directoryInfo.Name != directoryInfo_Parent.Name)
                    {
                        continue;
                    }

                    string[] fileSystemEntities = Directory.GetFileSystemEntries(directory_Temp, "*", SearchOption.TopDirectoryOnly);
                    if (fileSystemEntities != null && fileSystemEntities.Length != 0)
                    {
                        continue;
                    }

                    result.Add(directory_Temp);
                    Directory.Delete(directory_Temp, true);
                }
            }

            return result;
        }
    }
}