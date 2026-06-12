using System;

namespace DiGi.Maintenance.Classes
{
    /// <summary>
    /// Represents a software solution, tracking its location on disk and its version information.
    /// </summary>
    public class Solution
    {
        /// <summary>
        /// Gets the file system path to the solution file.
        /// </summary>
        public string? Path { get; }

        /// <summary>
        /// Gets or sets the version of the solution.
        /// </summary>
        public Version? Version { get; set; }

        /// <summary>
        /// Initializes a new instance of the <see cref="Solution"/> class.
        /// </summary>
        /// <param name="path">The file system path to the solution file.</param>
        /// <param name="version">The version associated with the solution.</param>
        public Solution(string? path, Version? version)
        {
            Path = path;
            Version = version;
        }

        /// <summary>
        /// Retrieves the filename of the solution without its extension.
        /// </summary>
        /// <returns>The name of the solution file if the <see cref="Path"/> is not null or whitespace; otherwise, <c>null</c>.</returns>
        public string? GetName()
        {
            if (string.IsNullOrWhiteSpace(Path))
            {
                return null;
            }

            return System.IO.Path.GetFileNameWithoutExtension(Path);
        }

        /// <summary>
        /// Retrieves the directory path containing the solution file.
        /// </summary>
        /// <returns>The directory path if the <see cref="Path"/> is not null or whitespace; otherwise, <c>null</c>.</returns>
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