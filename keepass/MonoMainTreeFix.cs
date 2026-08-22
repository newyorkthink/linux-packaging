using System;
using System.Drawing;
using System.Reflection;
using System.Windows.Forms;
using KeePass.Plugins;

[assembly: AssemblyTitle("Mono Main Tree Scroll Fix")]
[assembly: AssemblyDescription("Restores mouse-wheel scrolling in KeePass' main group tree on Mono.")]
[assembly: AssemblyCompany("wx-projects")]
[assembly: AssemblyProduct("KeePass Plugin")]
[assembly: AssemblyVersion("1.0.0.0")]
[assembly: AssemblyFileVersion("1.0.0.0")]

namespace MonoMainTreeFix
{
    public sealed class MonoMainTreeFixExt : Plugin, IMessageFilter
    {
        private const int WmMouseWheel = 0x020A;
        private const int WheelDelta = 120;
        private const string MainFormType = "KeePass.Forms.MainForm";
        private const string GroupsTreeName = "m_tvGroups";

        public override bool Initialize(IPluginHost host)
        {
            if(host == null) return false;

            Application.AddMessageFilter(this);
            return true;
        }

        public override void Terminate()
        {
            Application.RemoveMessageFilter(this);
        }

        public bool PreFilterMessage(ref Message m)
        {
            if(m.Msg != WmMouseWheel) return false;

            int delta = GetWheelDelta(m.WParam);
            if(delta == 0) return false;

            Form mainForm = FindMainForm();
            if(mainForm == null) return false;

            TreeView groups = Find(mainForm, GroupsTreeName) as TreeView;
            if((groups == null) || groups.IsDisposed || !groups.Visible ||
                !groups.Enabled || (groups.Nodes.Count == 0))
                return false;

            Rectangle bounds;
            try
            {
                bounds = groups.RectangleToScreen(groups.ClientRectangle);
            }
            catch
            {
                return false;
            }

            if(!bounds.Contains(Control.MousePosition)) return false;
            return ScrollTree(groups, delta);
        }

        private static Form FindMainForm()
        {
            foreach(Form form in Application.OpenForms)
            {
                if((form != null) && form.Visible &&
                    string.Equals(form.GetType().FullName, MainFormType,
                        StringComparison.Ordinal))
                    return form;
            }

            return null;
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

        private static int GetWheelDelta(IntPtr wParam)
        {
            long value = wParam.ToInt64();
            return unchecked((short)((value >> 16) & 0xFFFF));
        }

        private static bool ScrollTree(TreeView tree, int delta)
        {
            try
            {
                TreeNode current = tree.TopNode;
                if(current == null)
                {
                    if(tree.Nodes.Count == 0) return false;
                    current = tree.Nodes[0];
                }

                int lines = SystemInformation.MouseWheelScrollLines;
                if(lines <= 0) lines = 3;

                int notches = Math.Abs(delta) / WheelDelta;
                if(notches < 1) notches = 1;

                int step = lines * notches;
                bool scrollUp = (delta > 0);
                TreeNode target = current;

                for(int i = 0; i < step; ++i)
                {
                    TreeNode next = (scrollUp ? target.PrevVisibleNode :
                        target.NextVisibleNode);
                    if(next == null) break;
                    target = next;
                }

                tree.TopNode = target;
                tree.Invalidate();
                tree.Update();
                return true;
            }
            catch
            {
                return false;
            }
        }
    }
}
