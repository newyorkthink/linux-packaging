using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Text;
using System.Reflection;
using System.Windows.Forms;
using KeePass.Plugins;

[assembly: AssemblyTitle("Mono MessageBox Text Fix")]
[assembly: AssemblyDescription("Restores Mono WinForms MessageBox button labels without changing dialog behavior.")]
[assembly: AssemblyCompany("wx-projects")]
[assembly: AssemblyProduct("KeePass Plugin")]
[assembly: AssemblyVersion("1.2.0.0")]
[assembly: AssemblyFileVersion("1.2.0.0")]

namespace MonoMessageBoxFix
{
    public sealed class MonoMessageBoxFixExt : Plugin, IMessageFilter
    {
        private const string NestedMessageBoxFormType =
            "System.Windows.Forms.MessageBox+MessageBoxForm";
        private const string FlatMessageBoxFormType =
            "System.Windows.Forms.MessageBoxForm";

        private readonly Dictionary<Button, string> m_labels =
            new Dictionary<Button, string>();
        private Timer m_timer = null;

        public override bool Initialize(IPluginHost host)
        {
            if(host == null) return false;

            Application.AddMessageFilter(this);
            m_timer = new Timer();
            m_timer.Interval = 50;
            m_timer.Tick += this.OnTimerTick;
            m_timer.Start();
            return true;
        }

        public override void Terminate()
        {
            Application.RemoveMessageFilter(this);

            if(m_timer != null)
            {
                m_timer.Stop();
                m_timer.Tick -= this.OnTimerTick;
                m_timer.Dispose();
                m_timer = null;
            }

            List<Button> buttons = new List<Button>(m_labels.Keys);
            foreach(Button button in buttons)
            {
                if((button == null) || button.IsDisposed) continue;
                button.Paint -= this.OnButtonPaint;
                button.Disposed -= this.OnButtonDisposed;
            }
            m_labels.Clear();
        }

        public bool PreFilterMessage(ref Message m)
        {
            try
            {
                Control control = Control.FromHandle(m.HWnd);
                Form form = ((control != null) ? control.FindForm() : null);
                if((form != null) && form.Visible) FixMessageBox(form);
            }
            catch
            {
            }

            return false;
        }

        private void OnTimerTick(object sender, EventArgs e)
        {
            List<Form> forms = new List<Form>();
            foreach(Form form in Application.OpenForms) forms.Add(form);

            foreach(Form form in forms)
            {
                if((form == null) || form.IsDisposed || !form.Visible) continue;
                FixMessageBox(form);
            }
        }

        private void FixMessageBox(Form form)
        {
            Type type = form.GetType();
            string typeName = type.FullName;
            if(!string.Equals(typeName, NestedMessageBoxFormType,
                StringComparison.Ordinal) &&
                !string.Equals(typeName, FlatMessageBoxFormType,
                StringComparison.Ordinal))
                return;

            try
            {
                FieldInfo buttonsField = type.GetField("buttons",
                    BindingFlags.Instance | BindingFlags.NonPublic);
                FieldInfo kindField = type.GetField("msgbox_buttons",
                    BindingFlags.Instance | BindingFlags.NonPublic);
                if((buttonsField == null) || (kindField == null)) return;

                Button[] buttons = buttonsField.GetValue(form) as Button[];
                if(buttons == null) return;

                object kindValue = kindField.GetValue(form);
                if(!(kindValue is MessageBoxButtons)) return;

                string[] labels = GetLabels((MessageBoxButtons)kindValue);
                if(labels == null) return;

                int count = Math.Min(buttons.Length, labels.Length);
                for(int i = 0; i < count; ++i)
                {
                    Button button = buttons[i];
                    if((button == null) || button.IsDisposed ||
                        m_labels.ContainsKey(button))
                        continue;

                    string label = labels[i];
                    button.UseCompatibleTextRendering = true;
                    button.UseMnemonic = true;
                    button.TextAlign = ContentAlignment.MiddleCenter;
                    button.ForeColor = SystemColors.ControlText;
                    button.Text = label;

                    // Mono draws the button before raising Paint. Draw the label
                    // again in Paint so it remains visible when the theme's native
                    // text renderer produces an empty button face.
                    m_labels.Add(button, label);
                    button.Paint += this.OnButtonPaint;
                    button.Disposed += this.OnButtonDisposed;
                    button.Refresh();
                }
            }
            catch
            {
            }
        }

        private void OnButtonPaint(object sender, PaintEventArgs e)
        {
            Button button = sender as Button;
            string label;
            if((button == null) || !m_labels.TryGetValue(button, out label) ||
                string.IsNullOrEmpty(label))
                return;

            using(StringFormat format = new StringFormat())
            {
                format.Alignment = StringAlignment.Center;
                format.LineAlignment = StringAlignment.Center;
                format.FormatFlags = StringFormatFlags.NoWrap;
                format.HotkeyPrefix = HotkeyPrefix.Show;

                Brush brush = (button.Enabled ? SystemBrushes.ControlText :
                    SystemBrushes.GrayText);
                e.Graphics.DrawString(label, button.Font, brush,
                    button.ClientRectangle, format);
            }
        }

        private void OnButtonDisposed(object sender, EventArgs e)
        {
            Button button = sender as Button;
            if(button == null) return;

            button.Paint -= this.OnButtonPaint;
            button.Disposed -= this.OnButtonDisposed;
            m_labels.Remove(button);
        }

        private static string[] GetLabels(MessageBoxButtons buttons)
        {
            switch(buttons)
            {
                case MessageBoxButtons.OK:
                    return new string[] { GetKeePassText("OK", "OK") };
                case MessageBoxButtons.OKCancel:
                    return new string[] {
                        GetKeePassText("OK", "OK"),
                        GetKeePassText("Cancel", "Cancel")
                    };
                case MessageBoxButtons.AbortRetryIgnore:
                    return new string[] {
                        GetKeePassText("Abort", "Abort"),
                        GetKeePassText("Retry", "Retry"),
                        GetKeePassText("Ignore", "Ignore")
                    };
                case MessageBoxButtons.YesNoCancel:
                    return new string[] {
                        GetKeePassText("Yes", "Yes"),
                        GetKeePassText("No", "No"),
                        GetKeePassText("Cancel", "Cancel")
                    };
                case MessageBoxButtons.YesNo:
                    return new string[] {
                        GetKeePassText("Yes", "Yes"),
                        GetKeePassText("No", "No")
                    };
                case MessageBoxButtons.RetryCancel:
                    return new string[] {
                        GetKeePassText("Retry", "Retry"),
                        GetKeePassText("Cancel", "Cancel")
                    };
                default:
                    return null;
            }
        }

        private static string GetKeePassText(string propertyName,
            string fallback)
        {
            try
            {
                Type resourceType = typeof(Plugin).Assembly.GetType(
                    "KeePass.Resources.KPRes", false);
                if(resourceType != null)
                {
                    PropertyInfo property = resourceType.GetProperty(propertyName,
                        BindingFlags.Public | BindingFlags.Static);
                    if(property != null)
                    {
                        string value = property.GetValue(null, null) as string;
                        if(!string.IsNullOrEmpty(value)) return value;
                    }
                }
            }
            catch
            {
            }

            return fallback;
        }
    }
}
