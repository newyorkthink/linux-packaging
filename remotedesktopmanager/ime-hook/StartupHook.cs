using Avalonia;
using Avalonia.Input;
using Avalonia.Input.TextInput;
using Avalonia.Interactivity;

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
            Console.Error.WriteLine("rdm-ime-hook: register failed: " + ex);
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

        Console.Error.WriteLine("rdm-ime-hook: terminal IME client registered");
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

    public override Rect CursorRectangle =>
        _visual is null ? new Rect(0, 0, 1, 18) : new Rect(new Size(1, 18));

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
