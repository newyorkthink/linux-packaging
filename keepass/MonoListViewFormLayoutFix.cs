using System;
using System.Collections.Generic;
using System.Drawing;
using System.Reflection;
using System.Windows.Forms;
using KeePass.Plugins;

[assembly: AssemblyTitle("Mono List View Form Layout Fix")]
[assembly: AssemblyDescription("Keeps KeePass report-list banners, toolbars and content correctly positioned on Mono.")]
[assembly: AssemblyCompany("wx-projects")]
[assembly: AssemblyProduct("KeePass Plugin")]
[assembly: AssemblyVersion("1.0.0.0")]
[assembly: AssemblyFileVersion("1.0.0.0")]

namespace MonoListViewFormLayoutFix
{
    public sealed class MonoListViewFormLayoutFixExt : Plugin
    {
        private const string ListViewFormType = "KeePass.Forms.ListViewForm";

        private readonly HashSet<Form> m_patched = new HashSet<Form>();
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

            foreach(Form form in new List<Form>(m_patched))
                Detach(form);
        }

        private void OnTimerTick(object sender, EventArgs e)
        {
            List<Form> forms = new List<Form>();
            foreach(Form form in Application.OpenForms) forms.Add(form);

            foreach(Form form in forms)
            {
                if((form == null) || form.IsDisposed || !form.Visible ||
                    !string.Equals(form.GetType().FullName, ListViewFormType,
                        StringComparison.Ordinal))
                    continue;

                if(!m_patched.Contains(form))
                {
                    form.Resize += this.OnFormResize;
                    form.FormClosed += this.OnFormClosed;
                    m_patched.Add(form);
                }

                ApplyLayout(form);
            }
        }

        private void OnFormResize(object sender, EventArgs e)
        {
            Form form = sender as Form;
            if((form != null) && !form.IsDisposed) ApplyLayout(form);
        }

        private void OnFormClosed(object sender, FormClosedEventArgs e)
        {
            Form form = sender as Form;
            if(form != null) Detach(form);
        }

        private void Detach(Form form)
        {
            if(form == null) return;

            form.Resize -= this.OnFormResize;
            form.FormClosed -= this.OnFormClosed;
            m_patched.Remove(form);
        }

        private static void ApplyLayout(Form form)
        {
            int width = form.ClientSize.Width;
            int height = form.ClientSize.Height;
            if((width < 240) || (height < 180)) return;

            Control banner = Find(form, "m_bannerImage");
            Control toolbar = Find(form, "m_tsMain");
            Control info = Find(form, "m_lblInfo");
            ListView list = Find(form, "m_lvMain") as ListView;
            if((banner == null) || (toolbar == null) || (list == null)) return;

            form.SuspendLayout();
            try
            {
                int bannerHeight = Math.Max(1, banner.Height);
                int toolbarHeight = Math.Max(1, toolbar.Height);

                banner.Dock = DockStyle.None;
                banner.Bounds = new Rectangle(0, 0, width, bannerHeight);
                banner.Anchor = AnchorStyles.Top | AnchorStyles.Left |
                    AnchorStyles.Right;

                toolbar.Dock = DockStyle.None;
                toolbar.Bounds = new Rectangle(0, banner.Bottom, width,
                    toolbarHeight);
                toolbar.Anchor = AnchorStyles.Top | AnchorStyles.Left |
                    AnchorStyles.Right;

                int listTop = toolbar.Bottom + 5;
                if(info != null)
                {
                    int infoHeight = Math.Max(1, info.Height);
                    info.Bounds = new Rectangle(9, listTop,
                        Math.Max(80, width - 18), infoHeight);
                    info.Anchor = AnchorStyles.Top | AnchorStyles.Left |
                        AnchorStyles.Right;
                    listTop = info.Bottom + 5;
                }

                list.Bounds = new Rectangle(12, listTop,
                    Math.Max(80, width - 24),
                    Math.Max(40, height - listTop - 12));
                list.Anchor = AnchorStyles.Top | AnchorStyles.Bottom |
                    AnchorStyles.Left | AnchorStyles.Right;

                ResizeLastColumn(list);
                banner.BringToFront();
                toolbar.BringToFront();
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
