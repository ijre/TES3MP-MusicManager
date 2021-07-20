using System;
using System.IO;
using Microsoft.WindowsAPICodePack.Shell;
using Microsoft.WindowsAPICodePack.Shell.PropertySystem;

namespace GetFileProperties
{
  class Program
  {
    static void Main(string[] args)
    {
      if (args.Length != 1)
      {
#if _NDEBUG
        Console.WriteLine("Only need one argument, requiring the full path + track name.");
        return;
#elif _DEBUG
        args = new[] { @"C:\Program Files (x86)\Steam\steamapps\common\Morrowind\Data Files\Music\Custom/A Theme To Shop By.mp3" };
#endif
      }

      var file = ShellFile.FromFilePath(args[0]);

      Console.Write(file.Properties.System.Media.Duration.FormatForDisplay(PropertyDescriptionFormatOptions.LongTime));
    }
  }
}
