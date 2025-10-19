using System.Windows;
using DiGi.Maintenance.UI.Application.Windows;

namespace DiGi.Maintenance.UI.Application
{
    /// <summary>
    /// Interaction logic for App.xaml
    /// </summary>
    public partial class App : System.Windows.Application
    {
        void App_Startup(object sender, StartupEventArgs e)
        {
            MainWindow mainWindow = new();
            mainWindow.ShowDialog();

            Shutdown();
        }
    }

}
