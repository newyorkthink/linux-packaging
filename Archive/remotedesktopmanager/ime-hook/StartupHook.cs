using Avalonia;
using Avalonia.Input;
using Avalonia.Input.TextInput;
using Avalonia.Interactivity;

// .NET 启动钩子：给没有 TextInputMethodClient 的终端控件补上 Avalonia IME 客户端。
// RDM 自带的 Devolutions.TerminalControl 不会请求 IME，Fcitx5 无法 ProcessKeyEvent，
// 选词键就会原样变成 VT 写进 LocalTerm PTY。
public class StartupHook
{
    public static void Initialize()
    {
        try
        {
            Register();
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine("rdm-ime-hook: 注册失败: " + ex);
        }
    }

    static void Register()
    {
        InputElement.TextInputMethodClientRequestedEvent.AddClassHandler<InputElement>(
            OnClientRequested,
            handledEventsToo: true);

        InputElement.KeyDownEvent.AddClassHandler<InputElement>(
            OnTunnelKeyDown,
            RoutingStrategies.Tunnel,
            handledEventsToo: true);

        Console.Error.WriteLine("rdm-ime-hook: 已为终端控件注册 Avalonia IME 客户端");
    }

    static void OnClientRequested(InputElement sender, TextInputMethodClientRequestedEventArgs e)
    {
        if (e.Client is not null)
            return;
        if (!IsTerminalControl(sender))
            return;
        if (sender is not Visual visual)
            return;

        TerminalImeClient.Instance.Attach(visual);
        e.Client = TerminalImeClient.Instance;
    }

    static void OnTunnelKeyDown(InputElement sender, KeyEventArgs e)
    {
        if (!TerminalImeClient.Instance.IsComposing)
            return;
        if (!IsTerminalControl(sender))
            return;
        if (IsModifier(e.Key))
            return;

        e.Handled = true;
    }

    static bool IsTerminalControl(object? source)
    {
        var name = source?.GetType().FullName ?? string.Empty;
        return name.Contains("Terminal", StringComparison.OrdinalIgnoreCase)
            || name.Contains("LocalTerm", StringComparison.OrdinalIgnoreCase);
    }

    static bool IsModifier(Key key) =>
        key is Key.LeftShift or Key.RightShift
            or Key.LeftCtrl or Key.RightCtrl
            or Key.LeftAlt or Key.RightAlt
            or Key.LWin or Key.RWin
            or Key.CapsLock;
}

sealed class TerminalImeClient : TextInputMethodClient
{
    public static readonly TerminalImeClient Instance = new();

    Visual? _visual;
    string _preedit = string.Empty;

    public bool IsComposing => _preedit.Length > 0;

    public void Attach(Visual visual)
    {
        if (!ReferenceEquals(_visual, visual))
        {
            _visual = visual;
            RaiseTextViewVisualChanged();
        }

        RaiseCursorRectangleChanged();
        RaiseSurroundingTextChanged();
    }

    public override Visual TextViewVisual => _visual!;

    public override bool SupportsPreedit => true;

    public override bool SupportsSurroundingText => true;

    public override string SurroundingText => string.Empty;

    public override Rect CursorRectangle => new Rect(0, 0, 1, 18);

    public override TextSelection Selection
    {
        get => default;
        set { }
    }

    public override void SetPreeditText(string? preeditText, int? cursorPos)
    {
        _preedit = preeditText ?? string.Empty;
    }
}
