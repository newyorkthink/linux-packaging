using System;
using System.CodeDom.Compiler;
using System.IO;
using System.Reflection;
using System.Text;
using KeePass.Plugins;

internal static class PrecompilePlgx
{
    private static int Main(string[] args)
    {
        if(args.Length != 1)
        {
            Console.Error.WriteLine("Usage: PrecompilePlgx <plugin.plgx>");
            return 2;
        }

        string plgxPath = Path.GetFullPath(args[0]);
        if(!File.Exists(plgxPath))
        {
            Console.Error.WriteLine("PLGX file not found: " + plgxPath);
            return 2;
        }

        try
        {
            MethodInfo loadPriv = typeof(PlgxPlugin).GetMethod("LoadPriv",
                BindingFlags.NonPublic | BindingFlags.Static);
            if(loadPriv == null)
                throw new MissingMethodException(typeof(PlgxPlugin).FullName,
                    "LoadPriv");

            loadPriv.Invoke(null, new object[] {
                plgxPath, null, false, true, false, null
            });

            string pluginName = Path.GetFileNameWithoutExtension(plgxPath);
            string cacheRoot = PlgxCache.GetCacheRoot();
            if(!Directory.Exists(cacheRoot))
                throw new DirectoryNotFoundException(cacheRoot);

            string[] assemblies = Directory.GetFiles(cacheRoot,
                pluginName + ".dll", SearchOption.AllDirectories);
            if(assemblies.Length != 1)
                throw new InvalidOperationException(
                    "Expected exactly one compiled plugin assembly, found " +
                    assemblies.Length.ToString() + ".");

            if(string.Equals(pluginName, "KeePassOTP",
                StringComparison.OrdinalIgnoreCase))
            {
                string sourceRoot = Path.Combine(Environment.CurrentDirectory,
                    "keepass");
                CompileCompatibilityPlugin(
                    Path.Combine(sourceRoot, "MonoMessageBoxFix.cs"),
                    "/usr/share/keepass/Plugins/MonoMessageBoxFix.dll");
                CompileCompatibilityPlugin(
                    Path.Combine(sourceRoot, "MonoMainTreeFix.cs"),
                    "/usr/share/keepass/Plugins/MonoMainTreeFix.dll");
                CompileCompatibilityPlugin(
                    Path.Combine(sourceRoot, "MonoListViewFormLayoutFix.cs"),
                    "/usr/share/keepass/Plugins/MonoListViewFormLayoutFix.dll");
                CompileCompatibilityPlugin(
                    Path.Combine(sourceRoot, "MonoI3TabFocusFix.cs"),
                    "/usr/share/keepass/Plugins/MonoI3TabFocusFix.dll");
            }

            Console.WriteLine(assemblies[0]);
            return 0;
        }
        catch(TargetInvocationException ex)
        {
            Exception inner = ex.InnerException ?? ex;
            Console.Error.WriteLine(inner.ToString());
            return 1;
        }
        catch(Exception ex)
        {
            Console.Error.WriteLine(ex.ToString());
            return 1;
        }
    }

    private static void CompileCompatibilityPlugin(string sourcePath,
        string outputPath)
    {
        if(string.IsNullOrEmpty(sourcePath) || !File.Exists(sourcePath))
            throw new FileNotFoundException(
                "Compatibility plugin source was not found.", sourcePath);
        if(string.IsNullOrEmpty(outputPath))
            throw new ArgumentNullException("outputPath");

        string outputDirectory = Path.GetDirectoryName(outputPath);
        if(string.IsNullOrEmpty(outputDirectory) ||
            !Directory.Exists(outputDirectory))
            throw new DirectoryNotFoundException(outputDirectory);

        CompilerParameters parameters = new CompilerParameters();
        parameters.GenerateExecutable = false;
        parameters.GenerateInMemory = false;
        parameters.IncludeDebugInformation = false;
        parameters.OutputAssembly = outputPath;
        parameters.CompilerOptions = "-optimize+";
        parameters.ReferencedAssemblies.Add("/usr/share/keepass/KeePass.exe");
        parameters.ReferencedAssemblies.Add("System.dll");
        parameters.ReferencedAssemblies.Add("System.Core.dll");
        parameters.ReferencedAssemblies.Add("System.Drawing.dll");
        parameters.ReferencedAssemblies.Add("System.Windows.Forms.dll");

        CompilerResults results;
        using(CodeDomProvider provider = CodeDomProvider.CreateProvider("CSharp"))
            results = provider.CompileAssemblyFromFile(parameters,
                sourcePath);

        if(results.Errors.HasErrors)
        {
            StringBuilder message = new StringBuilder(
                "Failed to compile compatibility plugin: " + outputPath);
            foreach(CompilerError error in results.Errors)
                message.AppendLine().Append(error.ToString());
            throw new InvalidOperationException(message.ToString());
        }

        FileInfo output = new FileInfo(outputPath);
        if(!output.Exists || (output.Length == 0))
            throw new FileNotFoundException(
                "Compatibility plugin was not generated.", outputPath);
    }
}
