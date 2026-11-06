using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;

[assembly: AssemblyTitle("DeepSeek Harness Portable Launcher")]
[assembly: AssemblyDescription("Portable entry point for DeepSeek Harness")]
[assembly: AssemblyProduct("DeepSeek Harness Portable")]
[assembly: AssemblyVersion("1.0.0.0")]
[assembly: AssemblyFileVersion("1.0.0.0")]

namespace DshPortableLauncher
{
    internal static class Program
    {
        [DllImport("user32.dll")]
        private static extern bool SetProcessDPIAware();

        [STAThread]
        private static void Main(string[] args)
        {
            try
            {
                SetProcessDPIAware();
                string root = Locator.FindRoot(AppDomain.CurrentDomain.BaseDirectory);
                if (root == null)
                {
                    MessageBox.Show(
                        "未找到 DeepSeek Harness 便携运行时。\r\n\r\n" +
                        "请确认本程序位于便携根目录，或位于项目根目录且存在 release\\DSH-Portable。",
                        "DeepSeek Harness 便携版",
                        MessageBoxButtons.OK,
                        MessageBoxIcon.Error);
                    Environment.Exit(2);
                    return;
                }

                if (args.Length > 0)
                {
                    RunCommandLine(root, args);
                    return;
                }

                Application.EnableVisualStyles();
                Application.SetCompatibleTextRenderingDefault(false);
                Application.Run(new LauncherForm(root));
            }
            catch (Exception error)
            {
                MessageBox.Show(
                    "启动器发生错误：\r\n" + error.Message,
                    "DeepSeek Harness 便携版",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Error);
                Environment.Exit(1);
            }
        }

        private static void RunCommandLine(string root, string[] args)
        {
            string mode = args[0].Trim().ToLowerInvariant();
            if (mode == "desktop")
            {
                Environment.Exit(Commands.StartDesktop(root) ? 0 : 1);
            }
            if (mode == "--check-silent")
            {
                RunResult result = Commands.RunHidden(
                    root,
                    Path.Combine(root, "portable-tools", "validate-runtime.cmd"),
                    "--isolated",
                    Path.Combine(root, "logs", "launcher-check.log"),
                    300000);
                Environment.Exit(result.ExitCode);
            }
            if (mode == "check")
            {
                Commands.StartVisible(root, Path.Combine(root, "portable-tools", "validate-runtime.cmd"), "--isolated");
                Environment.Exit(0);
            }
            if (mode == "web")
            {
                Commands.StartVisible(root, Path.Combine(root, "start-web.cmd"), "");
                Environment.Exit(0);
            }
            if (mode == "menu")
            {
                Commands.StartVisible(root, Path.Combine(root, "preflight.cmd"), "");
                Environment.Exit(0);
            }
            Environment.Exit(2);
        }
    }

    internal static class Locator
    {
        public static string FindRoot(string baseDirectory)
        {
            string direct = baseDirectory.TrimEnd('\\');
            if (IsPortableRoot(direct))
            {
                return direct;
            }
            string nested = Path.Combine(direct, "release", "DSH-Portable");
            if (IsPortableRoot(nested))
            {
                return nested;
            }
            return null;
        }

        private static bool IsPortableRoot(string candidate)
        {
            return File.Exists(Path.Combine(candidate, "runtime", "node", "bin", "node.exe"))
                && File.Exists(Path.Combine(candidate, "app", "node_modules", "@deepseek-ai", "dsh", "lib", "bin.js"))
                && File.Exists(Path.Combine(candidate, "start-desktop.cmd"));
        }
    }

    internal sealed class RunResult
    {
        public int ExitCode;
        public string Output;
        public string LogPath;
    }

    internal static class Commands
    {
        public static bool StartDesktop(string root)
        {
            string script = Path.Combine(root, "start-desktop.cmd");
            ProcessStartInfo info = new ProcessStartInfo();
            info.FileName = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "cmd.exe");
            info.Arguments = "/d /c call \"" + script + "\"";
            info.WorkingDirectory = root;
            info.UseShellExecute = true;
            info.WindowStyle = ProcessWindowStyle.Hidden;
            Process.Start(info);

            string desktopPrefix = Path.Combine(root, "desktop") + "\\";
            bool processSeen = false;
            for (int attempt = 0; attempt < 120; attempt++)
            {
                System.Threading.Thread.Sleep(500);
                Process[] candidates = Process.GetProcessesByName("DeepSeek Harness");
                try
                {
                    for (int i = 0; i < candidates.Length; i++)
                    {
                        Process candidate = candidates[i];
                        try
                        {
                            string path = candidate.MainModule.FileName;
                            if (path != null && path.StartsWith(desktopPrefix, StringComparison.OrdinalIgnoreCase))
                            {
                                processSeen = true;
                                candidate.Refresh();
                                if (candidate.MainWindowHandle != IntPtr.Zero)
                                {
                                    return true;
                                }
                            }
                        }
                        catch { }
                    }
                }
                finally
                {
                    for (int i = 0; i < candidates.Length; i++)
                    {
                        candidates[i].Dispose();
                    }
                }
            }
            return processSeen;
        }

        public static RunResult RunHidden(string root, string script, string arguments, string logPath, int timeoutMs)
        {
            string logDirectory = Path.GetDirectoryName(logPath);
            if (!string.IsNullOrEmpty(logDirectory))
            {
                Directory.CreateDirectory(logDirectory);
            }

            ProcessStartInfo info = new ProcessStartInfo();
            info.FileName = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "cmd.exe");
            info.Arguments = "/d /c call \"" + script + "\"" + (string.IsNullOrEmpty(arguments) ? "" : " " + arguments);
            info.WorkingDirectory = root;
            info.UseShellExecute = false;
            info.CreateNoWindow = true;
            info.WindowStyle = ProcessWindowStyle.Hidden;
            info.RedirectStandardOutput = true;
            info.RedirectStandardError = true;
            info.StandardOutputEncoding = Encoding.UTF8;
            info.StandardErrorEncoding = Encoding.UTF8;

            StringBuilder output = new StringBuilder();
            object gate = new object();
            DataReceivedEventHandler append = delegate(object sender, DataReceivedEventArgs e)
            {
                if (e.Data == null) return;
                lock (gate)
                {
                    output.AppendLine(e.Data);
                }
            };

            int exitCode = -1;
            DateTime started = DateTime.Now;
            using (Process process = new Process())
            {
                process.StartInfo = info;
                process.OutputDataReceived += append;
                process.ErrorDataReceived += append;
                process.Start();
                process.BeginOutputReadLine();
                process.BeginErrorReadLine();
                bool finished = process.WaitForExit(timeoutMs);
                if (!finished)
                {
                    try { process.Kill(); } catch { }
                    lock (gate) output.AppendLine("[launcher] timed out after " + timeoutMs + " ms");
                }
                process.WaitForExit();
                exitCode = process.ExitCode;
            }

            string body;
            lock (gate) body = output.ToString();
            string header = "Started: " + started.ToString("yyyy-MM-dd HH:mm:ss") + "\r\n"
                + "Script: " + script + "\r\n"
                + "Arguments: " + arguments + "\r\n"
                + "ExitCode: " + exitCode + "\r\n\r\n";
            File.WriteAllText(logPath, header + body, new UTF8Encoding(false));

            RunResult result = new RunResult();
            result.ExitCode = exitCode;
            result.Output = body;
            result.LogPath = logPath;
            return result;
        }

        public static void StartVisible(string root, string script, string arguments)
        {
            ProcessStartInfo info = new ProcessStartInfo();
            info.FileName = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "cmd.exe");
            info.Arguments = "/d /k call \"" + script + "\"" + (string.IsNullOrEmpty(arguments) ? "" : " " + arguments);
            info.WorkingDirectory = root;
            info.UseShellExecute = true;
            info.WindowStyle = ProcessWindowStyle.Normal;
            Process.Start(info);
        }
    }

    internal sealed class LauncherForm : Form
    {
        private readonly string root;
        private Button desktopButton;
        private Button webButton;
        private Button checkButton;
        private Button menuButton;
        private Button readmeButton;
        private Button exitButton;
        private Label statusLabel;

        private static readonly Color Background = Color.FromArgb(23, 26, 33);
        private static readonly Color Surface = Color.FromArgb(40, 45, 56);
        private static readonly Color Accent = Color.FromArgb(58, 92, 255);
        private static readonly Color TextColor = Color.FromArgb(238, 241, 246);
        private static readonly Color Muted = Color.FromArgb(151, 160, 174);

        public LauncherForm(string root)
        {
            this.root = root;
            this.Text = "DeepSeek Harness 便携版";
            this.ClientSize = new Size(640, 360);
            this.FormBorderStyle = FormBorderStyle.FixedSingle;
            this.MaximizeBox = false;
            this.MinimizeBox = true;
            this.StartPosition = FormStartPosition.CenterScreen;
            this.BackColor = Background;
            this.ForeColor = TextColor;
            this.Font = new Font("Microsoft YaHei UI", 9.5F, FontStyle.Regular, GraphicsUnit.Point);
            try { this.Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath); } catch { }
            BuildInterface();
        }

        private void BuildInterface()
        {
            Panel accentBar = new Panel();
            accentBar.BackColor = Accent;
            accentBar.Bounds = new Rectangle(0, 0, 6, ClientSize.Height);
            Controls.Add(accentBar);

            PictureBox logo = new PictureBox();
            logo.Bounds = new Rectangle(34, 24, 54, 54);
            logo.SizeMode = PictureBoxSizeMode.Zoom;
            try
            {
                Icon appIcon = null;
                try { appIcon = new Icon(Application.ExecutablePath, 64, 64); }
                catch { appIcon = Icon.ExtractAssociatedIcon(Application.ExecutablePath); }
                if (appIcon != null) logo.Image = appIcon.ToBitmap();
            }
            catch { }
            Controls.Add(logo);

            Label title = new Label();
            title.Text = "DeepSeek Harness";
            title.ForeColor = TextColor;
            title.Font = new Font("Microsoft YaHei UI", 19F, FontStyle.Bold, GraphicsUnit.Point);
            title.Bounds = new Rectangle(100, 23, 340, 38);
            Controls.Add(title);

            Label badge = new Label();
            badge.Text = "便携版";
            badge.TextAlign = ContentAlignment.MiddleCenter;
            badge.BackColor = Accent;
            badge.ForeColor = Color.White;
            badge.Font = new Font("Microsoft YaHei UI", 9F, FontStyle.Bold, GraphicsUnit.Point);
            badge.Bounds = new Rectangle(430, 30, 78, 26);
            Controls.Add(badge);

            Label subtitle = new Label();
            subtitle.Text = "自包含运行环境 · 无需安装 Node.js / dsh";
            subtitle.ForeColor = Muted;
            subtitle.Bounds = new Rectangle(102, 63, 480, 22);
            Controls.Add(subtitle);

            Label rootLabel = new Label();
            rootLabel.Text = root;
            rootLabel.ForeColor = Color.FromArgb(112, 122, 138);
            rootLabel.AutoEllipsis = true;
            rootLabel.Bounds = new Rectangle(36, 101, 570, 20);
            Controls.Add(rootLabel);

            Panel divider = new Panel();
            divider.BackColor = Surface;
            divider.Bounds = new Rectangle(36, 130, 570, 1);
            Controls.Add(divider);

            desktopButton = CreateButton();
            desktopButton.Text = "启动桌面版\r\nDesktop";
            desktopButton.Bounds = new Rectangle(36, 150, 270, 64);
            desktopButton.BackColor = Accent;
            desktopButton.Font = new Font("Microsoft YaHei UI", 11F, FontStyle.Bold, GraphicsUnit.Point);
            desktopButton.Click += StartDesktop;
            Controls.Add(desktopButton);

            webButton = CreateButton();
            webButton.Text = "Web 版\r\n浏览器打开";
            webButton.Bounds = new Rectangle(318, 150, 142, 64);
            webButton.BackColor = Surface;
            webButton.Click += StartWeb;
            Controls.Add(webButton);

            checkButton = CreateButton();
            checkButton.Text = "自检 / 诊断";
            checkButton.Bounds = new Rectangle(472, 150, 134, 64);
            checkButton.BackColor = Surface;
            checkButton.Click += StartCheck;
            Controls.Add(checkButton);

            menuButton = CreateButton();
            menuButton.Text = "完整预检菜单";
            menuButton.Bounds = new Rectangle(36, 232, 142, 30);
            menuButton.BackColor = Color.FromArgb(31, 35, 44);
            menuButton.Font = new Font("Microsoft YaHei UI", 9F, FontStyle.Regular, GraphicsUnit.Point);
            menuButton.Click += delegate { StartVisibleScript("preflight.cmd", ""); };
            Controls.Add(menuButton);

            readmeButton = CreateButton();
            readmeButton.Text = "打开使用说明";
            readmeButton.Bounds = new Rectangle(188, 232, 142, 30);
            readmeButton.BackColor = Color.FromArgb(31, 35, 44);
            readmeButton.Font = new Font("Microsoft YaHei UI", 9F, FontStyle.Regular, GraphicsUnit.Point);
            readmeButton.Click += OpenReadme;
            Controls.Add(readmeButton);

            exitButton = CreateButton();
            exitButton.Text = "退出";
            exitButton.Bounds = new Rectangle(536, 232, 70, 30);
            exitButton.BackColor = Color.FromArgb(31, 35, 44);
            exitButton.Font = new Font("Microsoft YaHei UI", 9F, FontStyle.Regular, GraphicsUnit.Point);
            exitButton.Click += delegate { Close(); };
            Controls.Add(exitButton);

            Panel statusDivider = new Panel();
            statusDivider.BackColor = Surface;
            statusDivider.Bounds = new Rectangle(36, 286, 570, 1);
            Controls.Add(statusDivider);

            statusLabel = new Label();
            statusLabel.Text = "就绪";
            statusLabel.ForeColor = Muted;
            statusLabel.Bounds = new Rectangle(36, 299, 570, 40);
            Controls.Add(statusLabel);

            this.AcceptButton = desktopButton;
            this.CancelButton = exitButton;
        }

        private static Button CreateButton()
        {
            Button button = new Button();
            button.FlatStyle = FlatStyle.Flat;
            button.FlatAppearance.BorderSize = 0;
            button.ForeColor = Color.White;
            button.Cursor = Cursors.Hand;
            button.UseVisualStyleBackColor = false;
            button.TextAlign = ContentAlignment.MiddleCenter;
            button.MouseEnter += delegate(object sender, EventArgs e)
            {
                Button current = (Button)sender;
                if (!(current.Tag is Color)) current.Tag = current.BackColor;
                current.BackColor = Lighten(current.BackColor, 16);
            };
            button.MouseLeave += delegate(object sender, EventArgs e)
            {
                Button current = (Button)sender;
                current.BackColor = current.Tag is Color ? (Color)current.Tag : Surface;
            };
            return button;
        }

        private static Color Lighten(Color color, int amount)
        {
            return Color.FromArgb(
                Math.Min(255, color.R + amount),
                Math.Min(255, color.G + amount),
                Math.Min(255, color.B + amount));
        }

        private void SetBusy(string text)
        {
            desktopButton.Enabled = false;
            webButton.Enabled = false;
            checkButton.Enabled = false;
            menuButton.Enabled = false;
            readmeButton.Enabled = false;
            statusLabel.ForeColor = Color.FromArgb(195, 204, 218);
            statusLabel.Text = text;
            Cursor = Cursors.WaitCursor;
        }

        private void SetReady(string text)
        {
            desktopButton.Enabled = true;
            webButton.Enabled = true;
            checkButton.Enabled = true;
            menuButton.Enabled = true;
            readmeButton.Enabled = true;
            statusLabel.ForeColor = Muted;
            statusLabel.Text = text;
            Cursor = Cursors.Default;
        }

        private async void StartDesktop(object sender, EventArgs e)
        {
            SetBusy("正在启动桌面版，请稍候…");
            bool started = await Task.Run(delegate
            {
                return Commands.StartDesktop(root);
            });

            if (started)
            {
                statusLabel.Text = "桌面版已启动。";
                await Task.Delay(600);
                Close();
                return;
            }

            SetReady("启动失败。");
            MessageBox.Show(
                "没有检测到桌面窗口。\r\n\r\n" +
                "请运行“完整预检菜单”查看诊断，或检查：\r\n" +
                Path.Combine(root, "logs", "desktop-console.log"),
                "DeepSeek Harness 便携版",
                MessageBoxButtons.OK,
                MessageBoxIcon.Error);
        }

        private void StartWeb(object sender, EventArgs e)
        {
            StartVisibleScript("start-web.cmd", "");
        }

        private void StartCheck(object sender, EventArgs e)
        {
            StartVisibleScript(Path.Combine("portable-tools", "validate-runtime.cmd"), "--isolated");
        }

        private void StartVisibleScript(string relativeScript, string arguments)
        {
            try
            {
                Commands.StartVisible(root, Path.Combine(root, relativeScript), arguments);
                Close();
            }
            catch (Exception error)
            {
                MessageBox.Show(
                    "无法打开命令窗口：\r\n" + error.Message,
                    "DeepSeek Harness 便携版",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Error);
            }
        }

        private void OpenReadme(object sender, EventArgs e)
        {
            string readme = Path.Combine(root, "PORTABLE-README.md");
            if (!File.Exists(readme))
            {
                MessageBox.Show("找不到 PORTABLE-README.md。", "DeepSeek Harness 便携版", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }
            try
            {
                ProcessStartInfo info = new ProcessStartInfo();
                info.FileName = readme;
                info.UseShellExecute = true;
                Process.Start(info);
            }
            catch (Exception error)
            {
                MessageBox.Show("无法打开说明：" + error.Message, "DeepSeek Harness 便携版", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }

        private static string Tail(string text, int maxChars)
        {
            if (string.IsNullOrEmpty(text)) return "(无输出)";
            if (text.Length <= maxChars) return text;
            return "..." + text.Substring(text.Length - maxChars);
        }
    }
}
