using DiGi.Maintenance.UI.Windows;
using System.Windows;

namespace DiGi.Maintenance.UI.Application
{
    /// <summary>
    /// Interaction logic for App.xaml
    /// </summary>
    public partial class App : System.Windows.Application
    {
        private void App_Startup(object sender, StartupEventArgs e)
        {
            SolutionsWindow solutionsWindow = new();
            solutionsWindow.ShowDialog();

            Shutdown();
        }
    }
}