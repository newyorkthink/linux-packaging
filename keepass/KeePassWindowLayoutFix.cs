using System;
using System.Collections;
using System.Collections.Generic;
using System.Drawing;
using System.Reflection;
using System.Windows.Forms;
using KeePass.Plugins;

[assembly: AssemblyTitle("KeePass Window Layout Fix")]
[assembly: AssemblyDescription("Makes KeePass option and plugin windows tile correctly and releases Mono's modal focus lock.")]
[assembly: AssemblyCompany("wx-projects")]
[assembly: AssemblyProduct("KeePass Plugin")]
[assembly: AssemblyVersion("1.0.0.0")]
[assembly: AssemblyFileVersion("1.0.0.0")]

namespace KeePassWindowLayoutFix
{
    public sealed class KeePassWindowLayoutFixExt : Plugin
    {
        private const string OptionsType = "KeePass.Forms.OptionsForm";
        private const string PluginsType = "KeePass.Forms.PluginsForm";
        private const string MainType = "KeePass.Forms.MainForm";

        private readonly HashSet<Form> m_patched = new HashSet<Form>();
        private readonly HashSet<Form> m_released = new HashSet<Form>();
        private readonly Dictionary<Form, PictureBox> m_bannerBoxes =
            new Dictionary<Form, PictureBox>();
        private readonly Dictionary<Form, Image> m_bannerSources =
            new Dictionary<Form, Image>();
        private readonly Dictionary<Form, Image> m_bannerGenerated =
            new Dictionary<Form, Image>();
        private Timer m_timer = null;

        private static readonly FieldInfo g_isModal = typeof(Form).GetField(
            "is_modal", BindingFlags.Instance | BindingFlags.NonPublic);
        private static readonly FieldInfo g_disabledByShowDialog =
            typeof(Form).GetField("disabled_by_showdialog",
                BindingFlags.Instance | BindingFlags.NonPublic);
        private static readonly MethodInfo g_setModal = FindSetModal();

        public override bool Initialize(IPluginHost host)
        {
            if(host == null) return false;

            m_timer = new Timer();
            m_timer.Interval = 200;
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

            foreach(Form form in new List<Form>(m_patched)) Detach(form);
            m_released.Clear();
        }

        private void OnTimerTick(object sender, EventArgs e)
        {
            List<Form> forms = new List<Form>();
            foreach(Form form in Application.OpenForms) forms.Add(form);

            foreach(Form form in forms)
            {
                if((form == null) || form.IsDisposed || !form.Visible ||
                    !IsTarget(form)) continue;

                if(!m_patched.Contains(form)) Patch(form);

                if(!m_released.Contains(form) && ReleaseMonoModalFocus(form))
                    m_released.Add(form);
            }
        }

        private static bool IsTarget(Form form)
        {
            if(form == null) return false;

            string name = form.GetType().FullName;
            if(string.IsNullOrEmpty(name)) return false;

            if(string.Equals(name, MainType, StringComparison.Ordinal))
                return false;

            if(!name.StartsWith("KeePass.Forms.", StringComparison.Ordinal))
                return false;

            return (Find(form, "m_bannerImage") != null);
        }

        private void Patch(Form form)
        {
            form.FormBorderStyle = FormBorderStyle.Sizable;
            form.MaximizeBox = true;
            form.MaximumSize = Size.Empty;
            form.AutoSize = false;
            form.Resize += this.OnFormResize;
            form.FormClosed += this.OnFormClosed;

            TabControl tabs = Find(form, "m_tabMain") as TabControl;
            if(tabs != null)
                tabs.SelectedIndexChanged += this.OnOptionsTabChanged;

            string name = form.GetType().FullName;

            if(string.Equals(name, OptionsType, StringComparison.Ordinal))
            {
                ListView security = Find(form, "m_lvSecurityOptions") as ListView;
                if(security != null)
                    security.MouseWheel += this.OnSecurityListMouseWheel;
            }

            if(!string.Equals(name, OptionsType, StringComparison.Ordinal) &&
                !string.Equals(name, PluginsType, StringComparison.Ordinal))
                InitializeGenericLayout(form);

            m_patched.Add(form);
            ApplyLayout(form);
        }

        private void OnFormResize(object sender, EventArgs e)
        {
            Form form = sender as Form;
            if((form != null) && !form.IsDisposed) ApplyLayout(form);
        }

        private void OnOptionsTabChanged(object sender, EventArgs e)
        {
            Control control = sender as Control;
            Form form = ((control != null) ? control.FindForm() : null);
            if((form != null) && !form.IsDisposed && m_patched.Contains(form))
                ApplyLayout(form);
        }

        private void OnSecurityListMouseWheel(object sender, MouseEventArgs e)
        {
            ListView list = sender as ListView;
            if((list == null) || list.IsDisposed || list.Scrollable ||
                (list.Items.Count == 0))
                return;

            try
            {
                list.BeginInvoke((MethodInvoker)delegate
                {
                    if(list.IsDisposed || list.Scrollable ||
                        (list.Items.Count == 0))
                        return;

                    ResetListToTop(list);
                });
            }
            catch
            {
            }
        }

        private void OnFormClosed(object sender, FormClosedEventArgs e)
        {
            Form form = sender as Form;
            if(form != null) Detach(form);
        }

        private void Detach(Form form)
        {
            form.Resize -= this.OnFormResize;
            form.FormClosed -= this.OnFormClosed;

            TabControl tabs = Find(form, "m_tabMain") as TabControl;
            if(tabs != null)
                tabs.SelectedIndexChanged -= this.OnOptionsTabChanged;

            ListView security = Find(form, "m_lvSecurityOptions") as ListView;
            if(security != null)
                security.MouseWheel -= this.OnSecurityListMouseWheel;

            RestoreBanner(form);
            m_patched.Remove(form);
            m_released.Remove(form);
        }

        private void ApplyLayout(Form form)
        {
            string name = form.GetType().FullName;
            if(string.Equals(name, OptionsType, StringComparison.Ordinal))
                LayoutOptions(form);
            else if(string.Equals(name, PluginsType, StringComparison.Ordinal))
                LayoutPlugins(form);
            else
                LayoutGenericBannerDialog(form);
        }

        private void LayoutOptions(Form form)
        {
            int w = form.ClientSize.Width, h = form.ClientSize.Height;
            if((w < 300) || (h < 250)) return;

            form.SuspendLayout();
            try
            {
                Control banner = Find(form, "m_bannerImage");
                Control tabs = Find(form, "m_tabMain");
                Control search = Find(form, "m_tbSearch");
                Control ok = Find(form, "m_btnOK");
                Control cancel = Find(form, "m_btnCancel");

                LayoutBanner(form, banner, w);
                PlaceBottomRight(cancel, w, h, 12);
                if(ok != null)
                {
                    int right = ((cancel != null) ? cancel.Left - 6 : w - 12);
                    ok.Location = new Point(right - ok.Width, h - 12 - ok.Height);
                    ok.Anchor = AnchorStyles.Right | AnchorStyles.Bottom;
                }

                if(search != null)
                {
                    int right = ((ok != null) ? ok.Left - 18 : w - 12);
                    search.Bounds = new Rectangle(12, h - 12 - search.Height,
                        Math.Max(100, right - 12), search.Height);
                    search.Anchor = AnchorStyles.Left | AnchorStyles.Right |
                        AnchorStyles.Bottom;
                }

                if(tabs != null)
                {
                    int top = ((banner != null) ? banner.Bottom + 6 : 66);
                    int bottom = ((search != null) ? search.Top - 9 : h - 41);
                    tabs.Bounds = new Rectangle(12, top, Math.Max(100, w - 24),
                        Math.Max(100, bottom - top));
                    tabs.Anchor = AnchorStyles.Top | AnchorStyles.Bottom |
                        AnchorStyles.Left | AnchorStyles.Right;
                    tabs.PerformLayout();
                }

                LayoutOptionsLists(form);
                LayoutFixedOptionPages(form);
            }
            finally { form.ResumeLayout(true); }
        }

        private static void LayoutOptionsLists(Form form)
        {
            Control page = Find(form, "m_tabAdvanced");
            Control list = Find(form, "m_lvAdvanced");
            Control button = Find(form, "m_btnProxy");
            if(page != null)
            {
                if(button != null)
                {
                    button.Location = new Point(page.ClientSize.Width - 7 - button.Width,
                        page.ClientSize.Height - 8 - button.Height);
                    button.Anchor = AnchorStyles.Right | AnchorStyles.Bottom;
                }
                FitList(list, page, 6, 12,
                    ((button != null) ? button.Top - 6 : page.ClientSize.Height - 9));
            }

            page = Find(form, "m_tabGui1");
            list = Find(form, "m_lvGuiOptions");
            if(page != null) FitList(list, page, 6, 12,
                page.ClientSize.Height - 9);

            page = Find(form, "m_tabPolicy");
            list = Find(form, "m_lvPolicy");
            Control restart = Find(form, "m_lblPolicyRestart");
            if(page != null)
            {
                MoveBottom(restart, page.ClientSize.Height - 22);
                FitList(list, page, 6, 46,
                    ((restart != null) ? restart.Top - 7 : page.ClientSize.Height - 29));
                Control intro = Find(form, "m_lblPolicyIntro");
                if(intro != null) intro.Width = Math.Max(80, page.ClientSize.Width - 6);
            }

            page = Find(form, "m_tabSecurity");
            list = Find(form, "m_lvSecurityOptions");
            if(page != null)
            {
                int bottom = page.ClientSize.Height - 22;
                MoveBottom(Find(form, "m_lblSecOpt"), bottom);
                MoveBottom(Find(form, "m_linkSecOptEx"), bottom);
                MoveBottom(Find(form, "m_linkSecOptAdm"), bottom);
                FitList(list, page, 6, 115, bottom - 7);
                UpdateListScrollability(list as ListView);
            }
        }

        private static void LayoutFixedOptionPages(Form form)
        {
            StretchPageRightEdge(Find(form, "m_tabIntegration"));
            StretchPageRightEdge(Find(form, "m_tabGui2"));
        }

        private static void StretchPageRightEdge(Control page)
        {
            if((page == null) || (page.ClientSize.Width < 200)) return;

            List<Control> candidates = new List<Control>();
            foreach(Control child in page.Controls)
            {
                if((child.Dock != DockStyle.None) || (child.Width < 120)) continue;
                if(!(child is GroupBox) && !(child is Panel)) continue;
                candidates.Add(child);
            }

            int targetRight = page.ClientSize.Width - 8;
            foreach(Control child in candidates)
            {
                bool hasRightNeighbor = false;
                foreach(Control other in candidates)
                {
                    if(object.ReferenceEquals(child, other)) continue;

                    int overlap = Math.Min(child.Bottom, other.Bottom) -
                        Math.Max(child.Top, other.Top);
                    if((overlap > 8) && (other.Right > (child.Right + 8)))
                    {
                        hasRightNeighbor = true;
                        break;
                    }
                }
                if(hasRightNeighbor) continue;

                int width = targetRight - child.Left;
                if(width > child.Width) child.Width = width;
                child.Anchor = child.Anchor | AnchorStyles.Right;
            }
        }

        private static void InitializeGenericLayout(Form form)
        {
            Control banner = Find(form, "m_bannerImage");
            if(banner == null) return;

            Size designedSize = InferDesignedClientSize(form, banner);

            form.SuspendLayout();
            try
            {
                foreach(Control child in form.Controls)
                    ConfigureGenericAnchors(child);

                ResizeGenericRoot(form, banner, designedSize);
            }
            finally
            {
                form.ResumeLayout(true);
            }
        }

        private static Size InferDesignedClientSize(Form form, Control banner)
        {
            int width = ((banner != null) ? banner.Width : 0);
            int height = ((banner != null) ? banner.Bottom : 0);

            foreach(Control child in form.Controls)
            {
                if(object.ReferenceEquals(child, banner)) continue;

                if(width <= 0)
                    width = Math.Max(width, child.Right + 12);

                height = Math.Max(height, child.Bottom + 12);
            }

            if(width < 200)
                width = Math.Min(form.ClientSize.Width, 200);

            if(height < 160)
                height = Math.Min(form.ClientSize.Height, 160);

            width = Math.Min(width, form.ClientSize.Width);
            height = Math.Min(height, form.ClientSize.Height);

            return new Size(width, height);
        }

        private static void ConfigureGenericAnchors(Control parent)
        {
            if(parent == null) return;

            foreach(Control child in parent.Controls)
            {
                ConfigureGenericAnchors(child);

                if(child.Dock != DockStyle.None) continue;

                child.Anchor = InferGenericAnchor(
                    child, child.Bounds, parent.ClientSize);
            }
        }

        private static void ResizeGenericRoot(Form form, Control banner,
            Size designedSize)
        {
            int deltaWidth = form.ClientSize.Width - designedSize.Width;
            int deltaHeight = form.ClientSize.Height - designedSize.Height;

            foreach(Control child in form.Controls)
            {
                if(object.ReferenceEquals(child, banner)) continue;
                if(child.Dock != DockStyle.None) continue;

                Rectangle bounds = child.Bounds;
                AnchorStyles anchor = InferGenericAnchor(
                    child, bounds, designedSize);

                child.Bounds = ApplyAnchoredBounds(
                    bounds, anchor, deltaWidth, deltaHeight);

                child.Anchor = anchor;
                child.PerformLayout();
            }

            form.PerformLayout();
        }

        private static AnchorStyles InferGenericAnchor(Control control,
            Rectangle bounds, Size parentSize)
        {
            AnchorStyles anchor = control.Anchor;

            int rightGap = parentSize.Width - bounds.Right;
            int bottomGap = parentSize.Height - bounds.Bottom;

            bool stretchWidth = IsHorizontalStretchControl(
                control, bounds, parentSize);

            bool stretchHeight = IsVerticalStretchControl(
                control, bounds, parentSize);

            if((anchor & AnchorStyles.Right) == 0)
            {
                if((rightGap <= 28) ||
                    (stretchWidth && ((bounds.Width * 2) >= parentSize.Width)))
                {
                    if(stretchWidth)
                        anchor |= AnchorStyles.Right;
                    else
                    {
                        anchor &= ~AnchorStyles.Left;
                        anchor |= AnchorStyles.Right;
                    }
                }
            }

            if((anchor & AnchorStyles.Bottom) == 0)
            {
                if((bottomGap <= 36) ||
                    (stretchHeight && ((bounds.Height * 2) >= parentSize.Height)))
                {
                    if(stretchHeight)
                        anchor |= AnchorStyles.Bottom;
                    else
                    {
                        anchor &= ~AnchorStyles.Top;
                        anchor |= AnchorStyles.Bottom;
                    }
                }
            }

            return anchor;
        }

        private static bool IsHorizontalStretchControl(Control control,
            Rectangle bounds, Size parentSize)
        {
            if((control is TabControl) ||
                (control is ListView) ||
                (control is TreeView) ||
                (control is DataGridView) ||
                (control is SplitContainer) ||
                (control is PropertyGrid) ||
                (control is Panel) ||
                (control is GroupBox) ||
                (control is TextBoxBase) ||
                (control is ComboBox) ||
                (control is ToolStrip))
                return true;

            Label label = control as Label;
            if((label != null) &&
                ((bounds.Width * 2) >= parentSize.Width))
                return true;

            return false;
        }

        private static bool IsVerticalStretchControl(Control control,
            Rectangle bounds, Size parentSize)
        {
            if((control is TabControl) ||
                (control is ListView) ||
                (control is TreeView) ||
                (control is DataGridView) ||
                (control is SplitContainer) ||
                (control is PropertyGrid) ||
                (control is Panel) ||
                (control is GroupBox))
                return true;

            TextBoxBase textBox = control as TextBoxBase;
            if((textBox != null) && textBox.Multiline)
                return true;

            return false;
        }

        private static Rectangle ApplyAnchoredBounds(Rectangle bounds,
            AnchorStyles anchor, int deltaWidth, int deltaHeight)
        {
            int x = bounds.X;
            int y = bounds.Y;
            int width = bounds.Width;
            int height = bounds.Height;

            bool left = ((anchor & AnchorStyles.Left) != 0);
            bool right = ((anchor & AnchorStyles.Right) != 0);
            bool top = ((anchor & AnchorStyles.Top) != 0);
            bool bottom = ((anchor & AnchorStyles.Bottom) != 0);

            if(left && right)
                width = Math.Max(20, width + deltaWidth);
            else if(!left && right)
                x += deltaWidth;

            if(top && bottom)
                height = Math.Max(20, height + deltaHeight);
            else if(!top && bottom)
                y += deltaHeight;

            return new Rectangle(x, y, width, height);
        }

        private void LayoutGenericBannerDialog(Form form)
        {
            int width = form.ClientSize.Width;
            if(width < 200) return;

            Control banner = Find(form, "m_bannerImage");
            LayoutGenericBanner(form, banner, width);
            ResizeAllListColumns(form);
        }

        private void LayoutGenericBanner(Form form, Control banner, int width)
        {
            if(banner == null) return;

            int originalTop = banner.Top;

            LayoutBanner(form, banner, width);

            banner.Top = originalTop;
            banner.Anchor = AnchorStyles.Top | AnchorStyles.Left |
                AnchorStyles.Right;
        }

        private static void ResizeAllListColumns(Control root)
        {
            if(root == null) return;

            ListView list = root as ListView;
            if(list != null)
                ResizeLastColumn(list);

            foreach(Control child in root.Controls)
                ResizeAllListColumns(child);
        }

        private void LayoutPlugins(Form form)
        {
            int w = form.ClientSize.Width, h = form.ClientSize.Height;
            if((w < 300) || (h < 300)) return;

            form.SuspendLayout();
            try
            {
                Control banner = Find(form, "m_bannerImage");
                Control close = Find(form, "m_btnClose");
                Control more = Find(form, "m_btnMore");
                Control open = Find(form, "m_btnOpenFolder");
                Control separator = Find(form, "m_lblSeparator");
                Control cache = Find(form, "m_grpCache");
                Control description = Find(form, "m_grpPluginDesc");
                Control list = Find(form, "m_lvPlugins");

                LayoutBanner(form, banner, w);
                int buttonTop = h - 12 - ((close != null) ? close.Height : 23);
                PlaceBottomRight(close, w, h, 12);
                if(more != null)
                {
                    more.Location = new Point(12, buttonTop);
                    more.Anchor = AnchorStyles.Left | AnchorStyles.Bottom;
                }
                if(open != null)
                {
                    open.Location = new Point(((more != null) ? more.Right + 6 : 12),
                        buttonTop);
                    open.Anchor = AnchorStyles.Left | AnchorStyles.Bottom;
                }

                int separatorTop = buttonTop - 9;
                if(separator != null)
                {
                    separator.Bounds = new Rectangle(0, separatorTop, w,
                        separator.Height);
                    separator.Anchor = AnchorStyles.Left | AnchorStyles.Right |
                        AnchorStyles.Bottom;
                }

                if(cache != null)
                {
                    cache.Bounds = new Rectangle(12,
                        separatorTop - 12 - cache.Height, Math.Max(100, w - 24),
                        cache.Height);
                    cache.Anchor = AnchorStyles.Left | AnchorStyles.Right |
                        AnchorStyles.Bottom;
                    LayoutCache(cache);
                }

                if(description != null)
                {
                    int bottom = ((cache != null) ? cache.Top - 6 : separatorTop - 12);
                    description.Bounds = new Rectangle(12, bottom - description.Height,
                        Math.Max(100, w - 24), description.Height);
                    description.Anchor = AnchorStyles.Left | AnchorStyles.Right |
                        AnchorStyles.Bottom;
                    Control text = Find(description, "m_lblSelectedPluginDesc");
                    if(text != null)
                    {
                        text.Bounds = new Rectangle(6, 16,
                            Math.Max(50, description.ClientSize.Width - 12),
                            Math.Max(20, description.ClientSize.Height - 32));
                        text.Anchor = AnchorStyles.Top | AnchorStyles.Bottom |
                            AnchorStyles.Left | AnchorStyles.Right;
                    }
                }

                if(list != null)
                {
                    int top = ((banner != null) ? banner.Bottom + 6 : 66);
                    int bottom = ((description != null) ? description.Top - 6 :
                        separatorTop - 12);
                    list.Bounds = new Rectangle(12, top, Math.Max(100, w - 24),
                        Math.Max(80, bottom - top));
                    list.Anchor = AnchorStyles.Top | AnchorStyles.Bottom |
                        AnchorStyles.Left | AnchorStyles.Right;
                    ResizeLastColumn(list as ListView);
                }
            }
            finally { form.ResumeLayout(true); }
        }

        private void LayoutBanner(Form form, Control banner, int width)
        {
            if(banner == null) return;

            int targetWidth = Math.Max(1, width);
            int targetHeight = Math.Max(1, banner.Height);
            banner.Bounds = new Rectangle(0, 0, targetWidth, targetHeight);
            banner.Anchor = AnchorStyles.Top | AnchorStyles.Left |
                AnchorStyles.Right;

            PictureBox picture = banner as PictureBox;
            if((picture == null) || (picture.Image == null)) return;

            Image source;
            if(!m_bannerSources.TryGetValue(form, out source))
            {
                source = picture.Image;
                m_bannerBoxes[form] = picture;
                m_bannerSources[form] = source;
            }

            Image generated;
            if(m_bannerGenerated.TryGetValue(form, out generated) &&
                (generated.Width == targetWidth) &&
                (generated.Height == targetHeight))
                return;

            Bitmap extended = new Bitmap(targetWidth, targetHeight);
            using(Graphics graphics = Graphics.FromImage(extended))
            {
                graphics.Clear(picture.BackColor);

                int copyWidth = Math.Min(source.Width, targetWidth);
                graphics.DrawImage(source,
                    new Rectangle(0, 0, copyWidth, targetHeight),
                    new Rectangle(0, 0, copyWidth, source.Height),
                    GraphicsUnit.Pixel);

                if(targetWidth > copyWidth)
                {
                    graphics.DrawImage(source,
                        new Rectangle(copyWidth, 0, targetWidth - copyWidth,
                            targetHeight),
                        new Rectangle(Math.Max(0, source.Width - 1), 0, 1,
                            source.Height),
                        GraphicsUnit.Pixel);
                }
            }

            picture.Image = extended;
            if(generated != null) generated.Dispose();
            m_bannerGenerated[form] = extended;
        }

        private void RestoreBanner(Form form)
        {
            PictureBox picture;
            Image source;
            Image generated;

            m_bannerBoxes.TryGetValue(form, out picture);
            m_bannerSources.TryGetValue(form, out source);
            m_bannerGenerated.TryGetValue(form, out generated);

            if((picture != null) && !picture.IsDisposed && (source != null))
            {
                try { picture.Image = source; }
                catch { }
            }

            if(generated != null)
            {
                try { generated.Dispose(); }
                catch { }
            }

            m_bannerBoxes.Remove(form);
            m_bannerSources.Remove(form);
            m_bannerGenerated.Remove(form);
        }

        private static void LayoutCache(Control cache)
        {
            Control clear = Find(cache, "m_btnClearCache");
            Control size = Find(cache, "m_lblCacheSize");
            Control deleteOld = Find(cache, "m_cbCacheDeleteOld");

            if(clear != null)
            {
                clear.Left = cache.ClientSize.Width - 11 - clear.Width;
                clear.Anchor = AnchorStyles.Top | AnchorStyles.Right;
            }
            if(size != null)
            {
                int right = ((clear != null) ? clear.Left - 6 :
                    cache.ClientSize.Width - 6);
                size.Width = Math.Max(50, right - size.Left);
                size.Anchor = AnchorStyles.Top | AnchorStyles.Left |
                    AnchorStyles.Right;
            }
            if(deleteOld != null)
                deleteOld.Anchor = AnchorStyles.Left | AnchorStyles.Bottom;
        }

        private static void FitList(Control list, Control page, int left,
            int top, int bottom)
        {
            if((list == null) || (page == null)) return;
            list.Bounds = new Rectangle(left, top,
                Math.Max(80, page.ClientSize.Width - left - 8),
                Math.Max(60, bottom - top));
            list.Anchor = AnchorStyles.Top | AnchorStyles.Bottom |
                AnchorStyles.Left | AnchorStyles.Right;
            ResizeLastColumn(list as ListView);
        }

        private static void UpdateListScrollability(ListView list)
        {
            if(list == null) return;

            try
            {
                if(list.Items.Count == 0)
                {
                    list.Scrollable = false;
                    return;
                }

                list.Scrollable = true;
                ResetListToTop(list);
                list.PerformLayout();

                int contentBottom = 0;
                foreach(ListViewItem item in list.Items)
                {
                    Rectangle bounds = item.Bounds;
                    if(bounds.Height <= 0) continue;

                    contentBottom = Math.Max(contentBottom, bounds.Bottom);
                }

                if(contentBottom <= 0) return;

                bool overflow =
                    (contentBottom > (list.ClientRectangle.Bottom - 1));

                list.Scrollable = overflow;

                if(!overflow)
                {
                    ResetListToTop(list);
                    list.Invalidate();
                }
            }
            catch
            {
            }
        }

        private static void ResetListToTop(ListView list)
        {
            if((list == null) || list.IsDisposed || (list.Items.Count == 0))
                return;

            try
            {
                list.TopItem = list.Items[0];
            }
            catch
            {
            }
        }

        private static void PlaceBottomRight(Control control, int w, int h,
            int margin)
        {
            if(control == null) return;
            control.Location = new Point(w - margin - control.Width,
                h - margin - control.Height);
            control.Anchor = AnchorStyles.Right | AnchorStyles.Bottom;
        }

        private static void MoveBottom(Control control, int top)
        {
            if(control == null) return;
            control.Top = top;
            control.Anchor = AnchorStyles.Left | AnchorStyles.Bottom;
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
            if(string.Equals(root.Name, name, StringComparison.Ordinal)) return root;
            foreach(Control child in root.Controls)
            {
                Control found = Find(child, name);
                if(found != null) return found;
            }
            return null;
        }

        private static MethodInfo FindSetModal()
        {
            try
            {
                Type type = typeof(Form).Assembly.GetType(
                    "System.Windows.Forms.XplatUI", false);
                return ((type != null) ? type.GetMethod("SetModal",
                    BindingFlags.Static | BindingFlags.NonPublic, null,
                    new Type[] { typeof(IntPtr), typeof(bool) }, null) : null);
            }
            catch { return null; }
        }

        private static bool ReleaseMonoModalFocus(Form form)
        {
            if((form == null) || !form.IsHandleCreated) return false;

            bool nativeReleased = false;
            bool modal = false;
            bool haveModal = false;

            if(g_isModal != null)
            {
                try
                {
                    modal = (bool)g_isModal.GetValue(form);
                    haveModal = true;
                }
                catch { }
            }

            if(haveModal && !modal) nativeReleased = true;
            else if(haveModal && modal && (g_setModal != null))
            {
                try
                {
                    // Keep ShowDialog's managed modal state for OK/Cancel,
                    // but remove Mono's native focus stack and modal X11 atom.
                    g_isModal.SetValue(form, false);
                    g_setModal.Invoke(null, new object[] { form.Handle, false });
                    nativeReleased = true;
                }
                catch { }
                finally
                {
                    try { g_isModal.SetValue(form, modal); }
                    catch { }
                }
            }

            bool formsReleased = ReleaseDisabledForms(form);
            return nativeReleased && formsReleased;
        }

        private static bool ReleaseDisabledForms(Form dialog)
        {
            bool found = false;
            IList disabled = null;

            if(g_disabledByShowDialog != null)
            {
                try
                {
                    disabled = g_disabledByShowDialog.GetValue(dialog) as IList;
                }
                catch { }
            }

            if(disabled != null)
            {
                foreach(object item in disabled)
                {
                    Form form = item as Form;
                    if((form == null) || form.IsDisposed ||
                        object.ReferenceEquals(form, dialog)) continue;

                    found = true;
                    if(!form.Enabled) form.Enabled = true;
                }
            }

            Form owner = dialog.Owner;
            if((owner != null) && !owner.IsDisposed)
            {
                found = true;
                if(!owner.Enabled) owner.Enabled = true;
            }

            return found;
        }
    }
}
