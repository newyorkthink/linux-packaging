using System;
using System.Collections.Generic;
using System.Drawing;
using System.Reflection;
using System.Runtime.CompilerServices;
using System.Windows.Forms;
using KeePass.Plugins;
using KeePassLib.Cryptography;

[assembly: AssemblyTitle("Mono Compatibility Fix")]
[assembly: AssemblyDescription("Fixes KeePass option-list and password-preview scrolling plus a Mono password-quality crash.")]
[assembly: AssemblyCompany("wx-projects")]
[assembly: AssemblyProduct("KeePass Plugin")]
[assembly: AssemblyVersion("1.2.0.0")]
[assembly: AssemblyFileVersion("1.2.0.0")]

namespace MonoMouseWheelFix
{
    public sealed class MonoMouseWheelFixExt : Plugin, IMessageFilter
    {
        private const int WmMouseWheel = 0x020A;
        private const int WheelDelta = 120;
        private const int MaxComparerFixRetries = 240;

        private static readonly SafeCharArrayComparer g_safeComparer =
            new SafeCharArrayComparer();

        private Timer m_retryTimer = null;
        private int m_retryCount = 0;

        public override bool Initialize(IPluginHost host)
        {
            if(host == null) return false;

            Application.AddMessageFilter(this);

            if(!InstallPopularPasswordsComparerFix())
            {
                m_retryTimer = new Timer();
                m_retryTimer.Interval = 250;
                m_retryTimer.Tick += this.OnRetryTimerTick;
                m_retryTimer.Start();
            }

            return true;
        }

        public override void Terminate()
        {
            Application.RemoveMessageFilter(this);
            StopRetryTimer();
        }

        private void OnRetryTimerTick(object sender, EventArgs e)
        {
            ++m_retryCount;
            if(InstallPopularPasswordsComparerFix() ||
                (m_retryCount >= MaxComparerFixRetries))
                StopRetryTimer();
        }

        private void StopRetryTimer()
        {
            if(m_retryTimer == null) return;

            m_retryTimer.Stop();
            m_retryTimer.Tick -= this.OnRetryTimerTick;
            m_retryTimer.Dispose();
            m_retryTimer = null;
        }

        public bool PreFilterMessage(ref Message m)
        {
            if(m.Msg != WmMouseWheel) return false;

            int delta = GetWheelDelta(m.WParam);
            if(delta == 0) return false;

            Form optionsForm = FindForm("KeePass.Forms.OptionsForm");
            if(optionsForm != null)
            {
                ListView listView = FindListViewAtPoint(optionsForm,
                    Control.MousePosition);
                if((listView != null) && listView.Enabled &&
                    (listView.Items.Count != 0))
                {
                    if(!listView.Scrollable)
                    {
                        ResetListViewToTop(listView);
                        return true;
                    }

                    return ScrollListView(listView, delta);
                }
            }

            Form generatorForm = FindForm("KeePass.Forms.PwGeneratorForm");
            if(generatorForm != null)
            {
                TextBox preview = FindPreviewTextBoxAtPoint(generatorForm,
                    Control.MousePosition);
                if((preview != null) && preview.Enabled && preview.Multiline)
                    return ScrollPreviewTextBox(preview, delta);
            }

            return false;
        }

        private static Form FindForm(string typeName)
        {
            foreach(Form form in Application.OpenForms)
            {
                if(form.Visible && string.Equals(form.GetType().FullName,
                    typeName, StringComparison.Ordinal))
                    return form;
            }

            return null;
        }

        private static ListView FindListViewAtPoint(Control root,
            Point screenPoint)
        {
            for(int i = root.Controls.Count - 1; i >= 0; --i)
            {
                Control child = root.Controls[i];
                if(!child.Visible) continue;

                Rectangle bounds;
                try
                {
                    bounds = child.RectangleToScreen(child.ClientRectangle);
                }
                catch
                {
                    continue;
                }

                if(!bounds.Contains(screenPoint)) continue;

                ListView listView = child as ListView;
                if(listView != null) return listView;

                ListView nested = FindListViewAtPoint(child, screenPoint);
                if(nested != null) return nested;
            }

            return root as ListView;
        }

        private static TextBox FindPreviewTextBoxAtPoint(Control root,
            Point screenPoint)
        {
            for(int i = root.Controls.Count - 1; i >= 0; --i)
            {
                Control child = root.Controls[i];
                if(!child.Visible) continue;

                Rectangle bounds;
                try
                {
                    bounds = child.RectangleToScreen(child.ClientRectangle);
                }
                catch
                {
                    continue;
                }

                if(!bounds.Contains(screenPoint)) continue;

                TextBox textBox = child as TextBox;
                if((textBox != null) && textBox.ReadOnly &&
                    string.Equals(textBox.Name, "m_tbPreview",
                        StringComparison.Ordinal))
                    return textBox;

                TextBox nested = FindPreviewTextBoxAtPoint(child, screenPoint);
                if(nested != null) return nested;
            }

            TextBox rootTextBox = root as TextBox;
            if((rootTextBox != null) && rootTextBox.ReadOnly &&
                string.Equals(rootTextBox.Name, "m_tbPreview",
                    StringComparison.Ordinal))
                return rootTextBox;

            return null;
        }

        private static int GetWheelDelta(IntPtr wParam)
        {
            long value = wParam.ToInt64();
            return unchecked((short)((value >> 16) & 0xFFFF));
        }

        private static bool ScrollListView(ListView listView, int delta)
        {
            int lines = SystemInformation.MouseWheelScrollLines;
            if(lines <= 0) lines = 3;

            int notches = Math.Abs(delta) / WheelDelta;
            if(notches < 1) notches = 1;

            bool scrollUp = (delta > 0);
            int current = FindVisibleBoundary(listView, scrollUp);
            if(current < 0)
            {
                try
                {
                    ListViewItem topItem = listView.TopItem;
                    if(topItem != null) current = topItem.Index;
                }
                catch
                {
                }
            }
            if(current < 0) current = (scrollUp ? 0 : -1);

            int step = lines * notches;
            int target = (scrollUp ? current - step : current + step);
            int lastIndex = listView.Items.Count - 1;
            if(target < 0) target = 0;
            if(target > lastIndex) target = lastIndex;

            try
            {
                // EnsureVisible stops as soon as the boundary item is visible,
                // which can leave Mono's scrollbar slightly short of either end.
                // TopItem writes the actual scroll value; Mono clamps the last
                // item to the exact maximum scroll position.
                if(scrollUp && (target == 0))
                    listView.TopItem = listView.Items[0];
                else if(!scrollUp && (target == lastIndex))
                    listView.TopItem = listView.Items[lastIndex];
                else
                    listView.Items[target].EnsureVisible();

                return true;
            }
            catch
            {
                return false;
            }
        }

        private static void ResetListViewToTop(ListView listView)
        {
            if((listView == null) || listView.IsDisposed ||
                (listView.Items.Count == 0))
                return;

            try
            {
                listView.TopItem = listView.Items[0];
                listView.Invalidate();
            }
            catch
            {
            }
        }

        private static int FindVisibleBoundary(ListView listView, bool first)
        {
            Rectangle client = listView.ClientRectangle;
            int result = -1;

            for(int i = 0; i < listView.Items.Count; ++i)
            {
                Rectangle bounds;
                try
                {
                    bounds = listView.Items[i].Bounds;
                }
                catch
                {
                    continue;
                }

                if((bounds.Height <= 0) || (bounds.Bottom <= client.Top) ||
                    (bounds.Top >= client.Bottom))
                    continue;

                if(first) return i;
                result = i;
            }

            return result;
        }

        private static bool ScrollPreviewTextBox(TextBox textBox, int delta)
        {
            try
            {
                int lines = SystemInformation.MouseWheelScrollLines;
                if(lines <= 0) lines = 3;

                int notches = Math.Abs(delta) / WheelDelta;
                if(notches < 1) notches = 1;

                int topChar = textBox.GetCharIndexFromPosition(new Point(1, 1));
                int bottomY = Math.Max(1, textBox.ClientSize.Height - 2);
                int bottomChar = textBox.GetCharIndexFromPosition(
                    new Point(1, bottomY));
                int topLine = textBox.GetLineFromCharIndex(topChar);
                int bottomLine = textBox.GetLineFromCharIndex(bottomChar);
                int selectionLine = textBox.GetLineFromCharIndex(
                    textBox.SelectionStart);

                int step = lines * notches;
                bool scrollUp = (delta > 0);
                int currentLine = (scrollUp ?
                    Math.Min(topLine, selectionLine) :
                    Math.Max(bottomLine, selectionLine));
                int targetLine = (scrollUp ? currentLine - step :
                    currentLine + step);
                int maxLine = Math.Max(0, textBox.Lines.Length - 1);
                if(targetLine < 0) targetLine = 0;
                if(targetLine > maxLine) targetLine = maxLine;

                int targetChar;
                if(!scrollUp && (targetLine >= maxLine))
                    targetChar = textBox.TextLength;
                else if(scrollUp && (targetLine <= 0))
                    targetChar = 0;
                else
                {
                    targetChar = textBox.GetFirstCharIndexFromLine(targetLine);
                    if(targetChar < 0) targetChar = textBox.TextLength;
                }

                textBox.SelectionStart = targetChar;
                textBox.SelectionLength = 0;
                textBox.ScrollToCaret();
                return true;
            }
            catch
            {
                return false;
            }
        }

        private static bool InstallPopularPasswordsComparerFix()
        {
            try
            {
                FieldInfo field = typeof(PopularPasswords).GetField("g_dicts",
                    BindingFlags.NonPublic | BindingFlags.Static);
                if(field == null) return false;

                Dictionary<int, HashSet<char[]>> dictionaries =
                    field.GetValue(null) as Dictionary<int, HashSet<char[]>>;
                if((dictionaries == null) || (dictionaries.Count == 0))
                    return false;

                List<int> keys = new List<int>(dictionaries.Keys);
                Dictionary<int, HashSet<char[]>> replacements =
                    new Dictionary<int, HashSet<char[]>>();
                bool found = false;

                foreach(int key in keys)
                {
                    HashSet<char[]> source = dictionaries[key];
                    if(source == null) continue;

                    found = true;
                    if(source.Comparer is SafeCharArrayComparer) continue;

                    HashSet<char[]> replacement =
                        new HashSet<char[]>(g_safeComparer);
                    foreach(char[] word in source)
                        replacement.Add(word);

                    if(replacement.Count != source.Count) return false;
                    replacements[key] = replacement;
                }

                foreach(KeyValuePair<int, HashSet<char[]>> replacement in replacements)
                    dictionaries[replacement.Key] = replacement.Value;

                return found;
            }
            catch
            {
                return false;
            }
        }

        private sealed class SafeCharArrayComparer : IEqualityComparer<char[]>
        {
            [MethodImpl(MethodImplOptions.NoInlining |
                MethodImplOptions.NoOptimization)]
            public bool Equals(char[] x, char[] y)
            {
                if(object.ReferenceEquals(x, y)) return true;
                if((x == null) || (y == null) || (x.Length != y.Length))
                    return false;

                for(int i = 0; i < x.Length; ++i)
                {
                    if(x[i] != y[i]) return false;
                }

                return true;
            }

            [MethodImpl(MethodImplOptions.NoInlining |
                MethodImplOptions.NoOptimization)]
            public int GetHashCode(char[] value)
            {
                if(value == null) return 0;

                unchecked
                {
                    int hash = 17;
                    for(int i = 0; i < value.Length; ++i)
                        hash = (hash * 31) + value[i];
                    return hash;
                }
            }
        }
    }
}
