using DiGi.Core;
using DiGi.Maintenance.Classes;
using Microsoft.Win32;
using System.IO;
using System.Windows;

namespace DiGi.Maintenance.UI.Windows
{
    /// <summary>
    /// Interaction logic for SolutionsWindow.xaml
    /// </summary>
    public partial class SolutionsWindow : Window
    {
        public SolutionsWindow()
        {
            InitializeComponent();
        }

        private void Button_CleanDirectories_Click(object sender, RoutedEventArgs e)
        {
            bool? result;

            OpenFolderDialog openFolderDialog;

            openFolderDialog = new OpenFolderDialog
            {
                Title = "Select directory"
            };

            result = openFolderDialog.ShowDialog(this);
            if (result == null || !result.HasValue || !result.Value)
            {
                return;
            }

            string directory = openFolderDialog.FolderName;

            HashSet<string>? directories = Maintenance.Modify.CleanDirectories(directory);

            if(directories == null)
            {
                directories = [];
            }

            File.WriteAllLines(Path.Combine(directory, "report.txt"), directories);
        }

        private void Button_Load_Click(object sender, RoutedEventArgs e)
        {
            bool? result;

            OpenFolderDialog openFolderDialog;

            openFolderDialog = new OpenFolderDialog
            {
                Title = "Select solutions directory"
            };

            result = openFolderDialog.ShowDialog(this);
            if (result == null || !result.HasValue || !result.Value)
            {
                return;
            }

            string directory_Solutions = openFolderDialog.FolderName;
            if (string.IsNullOrWhiteSpace(directory_Solutions) || !Directory.Exists(directory_Solutions))
            {
                return;
            }

            if (Maintenance.Create.MaintenanceConfigurationFile() is not MaintenanceConfigurationFile maintenanceConfigurationFile)
            {
                return;
            }

            maintenanceConfigurationFile.Add("DIRECTORY_SOLUTIONS", directory_Solutions);

            maintenanceConfigurationFile.Write();

            LoadSolutions();
        }

        private void Button_Sync_Click(object sender, RoutedEventArgs e)
        {
            if (Maintenance.Create.MaintenanceConfigurationFile() is not MaintenanceConfigurationFile maintenanceConfigurationFile)
            {
                return;
            }

            if (maintenanceConfigurationFile.GetValue<string>("DIRECTORY_SOLUTIONS") is not string directory_Solutions)
            {
                return;
            }

            string[] paths = Directory.GetFiles(directory_Solutions, "*.sln");
            if (paths == null)
            {
                return;
            }

            List<Solution> solutions = [];
            foreach (string path in paths)
            {
                Solution? solution = Maintenance.Create.Solution(path);
                if (solution is null)
                {
                    continue;
                }

                solutions.Add(solution);
            }

            if (solutions.Count == 0)
            {
                return;
            }

            GitHub.Classes.GitHubConfigurationFile? gitHubConfigurationFile = Create.GitHubConfigurationFile();
            if (gitHubConfigurationFile == null)
            {
                return;
            }

            string? commitMessage = null;

            DiGi.UI.WPF.Core.Windows.TextBoxWindow textBoxWindow = new("Commit", "Commit message:");

            bool? showDialog = textBoxWindow.ShowDialog();
            if(showDialog is not null && showDialog.HasValue)
            {
                if(!string.IsNullOrWhiteSpace(textBoxWindow.Value))
                {
                    commitMessage = textBoxWindow.Value;
                }
            }

            foreach (Solution solution in solutions)
            {
                Modify.Sync(gitHubConfigurationFile, solution, commitMessage);
            }
        }

        private void Button_Test_Click(object sender, RoutedEventArgs e)
        {
            DiGi.UI.WPF.Core.Windows.TextBoxWindow textBoxWindow = new("Commit", "Commit message:");
            textBoxWindow.Validation = new Func<string, bool>(x => { return x.All(char.IsDigit); });


            bool? showDialog = textBoxWindow.ShowDialog();
            if (showDialog is not null && showDialog.HasValue)
            {
                if (!string.IsNullOrWhiteSpace(textBoxWindow.Value))
                {
            
                }
            }
        }

        private void Button_UpdateSolution_Click(object sender, RoutedEventArgs e)
        {
            List<Solution>? solutions = ListBoxControl_Solutions.GetItems<Solution>(true);
            if (solutions is null || solutions.Count == 0)
            {
                return;
            }

            if (SolutionControl_Main.Solution is not Solution solution_Source)
            {
                return;
            }

            int major = -1;
            int minor = -1;
            int build = -1;

            if (solution_Source.Version is Version version)
            {
                major = version.Major;
                minor = version.Minor;
                build = version.Build;
            }

            foreach (Solution solution in solutions)
            {
                if (solution == null)
                {
                    continue;
                }

                int major_Solution = -1;
                int minor_Solution = -1;
                int build_Solution = -1;

                if (solution.Version is Version version_Solution)
                {
                    major_Solution = version_Solution.Major;
                    minor_Solution = version_Solution.Minor;
                    build_Solution = version_Solution.Build;
                }

                if (major != -1)
                {
                    major_Solution = major;
                }

                if (minor != -1)
                {
                    minor_Solution = minor;
                }

                if (build != -1)
                {
                    build_Solution = build;
                }

                if (major == -1 || minor == -1 || build == -1)
                {
                    continue;
                }

                solution.Version = new Version(major, minor, build);
                solution.Write();
            }
        }

        private void ListBoxControl_Solutions_ItemAdding(object sender, DiGi.UI.WPF.Core.Classes.ListBoxItemAddingEventArgs e)
        {
            if (e.Item is not Solution solution)
            {
                return;
            }

            e.Name = solution.GetName();
        }
        
        private void ListBoxControl_Solutions_SelectionChanged(object sender, System.Windows.Controls.SelectionChangedEventArgs e)
        {
            List<Solution>? solutions = ListBoxControl_Solutions.GetItems<Solution>(true);
            if (solutions is null || solutions.Count == 0)
            {
                SolutionControl_Main.Solution = null;
                return;
            }

            if (solutions.Count == 1)
            {
                SolutionControl_Main.Solution = solutions[0];
                return;
            }

            string? path = solutions[0]?.Path;
            int major = solutions[0].Version is null ? -1 : solutions[0].Version!.Major;
            int minor = solutions[0].Version is null ? -1 : solutions[0].Version!.Minor;
            int build = solutions[0].Version is null ? -1 : solutions[0].Version!.Build;

            foreach (Solution solution in solutions)
            {
                if (path != solution.Path)
                {
                    path = null;
                }

                if (major != solution.Version?.Major)
                {
                    major = -1;
                }

                if (minor != solution.Version?.Minor)
                {
                    minor = -1;
                }

                if (build != solution.Version?.Build)
                {
                    build = -1;
                }
            }

            SolutionControl_Main.Solution = new Solution(path, new Version(major, minor, build));

        }

        private void LoadSolutions()
        {
            ListBoxControl_Solutions.ClearItems();

            if (Maintenance.Create.MaintenanceConfigurationFile() is not MaintenanceConfigurationFile maintenanceConfigurationFile)
            {
                return;
            }

            if (maintenanceConfigurationFile.GetValue<string>("DIRECTORY_SOLUTIONS") is not string directory_Solutions)
            {
                return;
            }

            string[] paths = Directory.GetFiles(directory_Solutions, "*.sln", SearchOption.AllDirectories);
            if (paths == null)
            {
                return;
            }

            List<Solution> solutions = [];
            foreach (string path in paths)
            {
                Solution? solution = Maintenance.Create.Solution(path);
                if (solution?.Version is null)
                {
                    continue;
                }

                solutions.Add(solution);
            }

            if (solutions.Count == 0)
            {
                return;
            }

            ListBoxControl_Solutions.SetItems(solutions);
        }

        private void Window_Loaded(object sender, RoutedEventArgs e)
        {
            ListBoxControl_Solutions.SelectionMode = System.Windows.Controls.SelectionMode.Multiple;

            ListBoxControl_Solutions.ItemAdding += ListBoxControl_Solutions_ItemAdding;
            ListBoxControl_Solutions.SelectionChanged += ListBoxControl_Solutions_SelectionChanged;

            LoadSolutions();
        }
    }
}
