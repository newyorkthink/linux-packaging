using System;
using System.Collections.Generic;
using System.Drawing;
using System.Reflection;
using System.Windows.Forms;
using KeePass.Plugins;

[assembly: AssemblyTitle("Mono Columns Form Layout Fix")]
[assembly: AssemblyDescription("Keeps KeePass ColumnsForm controls correctly positioned when the dialog is tiled.")]
[assembly: AssemblyCompany("wx-projects")]
[assembly: AssemblyProduct("KeePass Plugin")]
[assembly: AssemblyVersion("1.2.0.0")]
[assembly: AssemblyFileVersion("1.2.0.0")]

namespace MonoI3TabFocusFix
{
    // 保留原文件名、命名空间和插件类名，避免无意义地改动现有构建接入；
    // 本插件只修复“列设置”平铺布局，不再尝试解除 Mono ShowDialog 的焦点限制。
    public sealed class MonoI3TabFocusFixExt : Plugin
    {
        private const string ColumnsType = "KeePass.Forms.ColumnsForm";

        private readonly HashSet<Form> m_columnsPatched = new HashSet<Form>();
        private Timer m_timer = null;

        public override bool Initialize(IPluginHost host)
        {
            if(host == null) return false;

            m_timer = new Timer();
            m_timer.Interval = 100;
            m_timer.Tick += this.OnTimerTick;
            m_timer.Start();
            return true;
        }

        public override void Terminate()
        {
            if(m_timer != null)
            {
                m_timer.Stop();
                m_timer.Tick -= this.OnTimerTick;
                m_timer.Dispose();
                m_timer = null;
            }

            foreach(Form form in new List<Form>(m_columnsPatched))
                DetachColumns(form);
        }

        private void OnTimerTick(object sender, EventArgs e)
        {
            List<Form> forms = new List<Form>();
            foreach(Form form in Application.OpenForms) forms.Add(form);

            foreach(Form form in forms)
            {
                if(!IsColumnsForm(form)) continue;

                if(!m_columnsPatched.Contains(form))
                {
                    form.Resize += this.OnColumnsResize;
                    form.FormClosed += this.OnColumnsClosed;
                    m_columnsPatched.Add(form);
                }

                ApplyColumnsLayout(form);
            }
        }

        private static bool IsColumnsForm(Form form)
        {
            return ((form != null) && !form.IsDisposed && form.Visible &&
                string.Equals(form.GetType().FullName, ColumnsType,
                    StringComparison.Ordinal));
        }

        private void OnColumnsResize(object sender, EventArgs e)
        {
            Form form = sender as Form;
            if((form != null) && !form.IsDisposed)
                ApplyColumnsLayout(form);
        }

        private void OnColumnsClosed(object sender, FormClosedEventArgs e)
        {
            Form form = sender as Form;
            if(form != null) DetachColumns(form);
        }

        private void DetachColumns(Form form)
        {
            if(form == null) return;

            if(!form.IsDisposed)
            {
                form.Resize -= this.OnColumnsResize;
                form.FormClosed -= this.OnColumnsClosed;
            }
            m_columnsPatched.Remove(form);
        }

        private static void ApplyColumnsLayout(Form form)
        {
            int w = form.ClientSize.Width, h = form.ClientSize.Height;
            if((w < 300) || (h < 250)) return;

            Control banner = Find(form, "m_bannerImage");
            Control choose = Find(form, "m_lblChoose");
            ListView list = Find(form, "m_lvColumns") as ListView;
            Control ok = Find(form, "m_btnOK");
            Control cancel = Find(form, "m_btnCancel");
            Control group = Find(form, "m_grpColumn");
            Control remember = Find(form, "m_cbRmbHidingPasswords");
            Control reorder = Find(form, "m_lblReorderHint");
            Control sort = Find(form, "m_lblSortHint");

            form.SuspendLayout();
            try
            {
                int buttonLeft = w - 12;
                if(ok != null)
                {
                    ok.Location = new Point(buttonLeft - ok.Width,
                        ((banner != null) ? banner.Bottom + 28 : 88));
                    ok.Anchor = AnchorStyles.Top | AnchorStyles.Right;
                    buttonLeft = ok.Left;
                }
                if(cancel != null)
                {
                    int top = ((ok != null) ? ok.Bottom + 6 :
                        ((banner != null) ? banner.Bottom + 57 : 117));
                    cancel.Location = new Point(w - 12 - cancel.Width, top);
                    cancel.Anchor = AnchorStyles.Top | AnchorStyles.Right;
                    buttonLeft = Math.Min(buttonLeft, cancel.Left);
                }

                if(choose != null)
                {
                    choose.Location = new Point(9,
                        ((banner != null) ? banner.Bottom + 12 : 72));
                    choose.Anchor = AnchorStyles.Top | AnchorStyles.Left;
                }

                if(sort != null)
                {
                    sort.Location = new Point(9, h - 11 - sort.Height);
                    sort.Anchor = AnchorStyles.Left | AnchorStyles.Bottom;
                }
                if(reorder != null)
                {
                    int top = ((sort != null) ? sort.Top - 6 - reorder.Height :
                        h - 30 - reorder.Height);
                    reorder.Location = new Point(9, top);
                    reorder.Anchor = AnchorStyles.Left | AnchorStyles.Bottom;
                }
                if(remember != null)
                {
                    int top = ((reorder != null) ?
                        reorder.Top - 3 - remember.Height :
                        h - 49 - remember.Height);
                    remember.Location = new Point(12, top);
                    remember.Anchor = AnchorStyles.Left | AnchorStyles.Bottom;
                }

                int contentRight = Math.Max(92, buttonLeft - 6);
                if(group != null)
                {
                    int top = ((remember != null) ?
                        remember.Top - 6 - group.Height : h - 114);
                    group.Bounds = new Rectangle(12, top,
                        Math.Max(80, contentRight - 12), group.Height);
                    group.Anchor = AnchorStyles.Left | AnchorStyles.Right |
                        AnchorStyles.Bottom;
                }

                if(list != null)
                {
                    int top = ((choose != null) ? choose.Bottom + 4 :
                        ((banner != null) ? banner.Bottom + 29 : 89));
                    int bottom = ((group != null) ? group.Top - 6 :
                        ((remember != null) ? remember.Top - 6 : h - 120));
                    list.Bounds = new Rectangle(12, top,
                        Math.Max(80, contentRight - 12),
                        Math.Max(20, bottom - top));
                    list.Anchor = AnchorStyles.Top | AnchorStyles.Bottom |
                        AnchorStyles.Left | AnchorStyles.Right;
                    ResizeLastColumn(list);
                }
            }
            finally
            {
                form.ResumeLayout(true);
            }
        }

        private static void ResizeLastColumn(ListView list)
        {
            if((list == null) || (list.Columns.Count == 0)) return;

            int used = 0;
            for(int i = 0; i < list.Columns.Count - 1; ++i)
                used += Math.Max(0, list.Columns[i].Width);

            int width = list.ClientSize.Width - used -
                SystemInformation.VerticalScrollBarWidth - 6;
            if(width >= 40) list.Columns[list.Columns.Count - 1].Width = width;
        }

        private static Control Find(Control root, string name)
        {
            if(root == null) return null;
            if(string.Equals(root.Name, name, StringComparison.Ordinal))
                return root;

            foreach(Control child in root.Controls)
            {
                Control found = Find(child, name);
                if(found != null) return found;
            }

            return null;
        }
    }
}
