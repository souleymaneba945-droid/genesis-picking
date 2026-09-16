#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <algorithm>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);

  // Taille/position calculées à partir de la zone de travail réelle de
  // l'écran (celle qui EXCLUT la barre des tâches Windows), plutôt que le
  // 1280x720 fixe du gabarit Flutter par défaut : sur un écran dont la
  // hauteur utile est inférieure à 720 (ex. un portable 1280x720, barre
  // des tâches déduite = ~680 de haut), la fenêtre par défaut débordait
  // sous la barre des tâches et cachait la barre de navigation de l'app
  // (12/09/2026, retour visuel direct). Toujours centrée, jamais plus
  // grande que 1280x720 sur un grand écran.
  RECT work_area = {0, 0, 1280, 720};
  ::SystemParametersInfoW(SPI_GETWORKAREA, 0, &work_area, 0);
  int work_width = work_area.right - work_area.left;
  int work_height = work_area.bottom - work_area.top;

  int width = std::min(1280, std::max(640, work_width - 40));
  int height = std::min(720, std::max(480, work_height - 40));
  int x = work_area.left + (work_width - width) / 2;
  int y = work_area.top + (work_height - height) / 2;

  Win32Window::Point origin(x, y);
  Win32Window::Size size(width, height);
  if (!window.Create(L"genesis_picking", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
