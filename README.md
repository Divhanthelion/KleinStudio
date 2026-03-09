# KleinStudio

KleinStudio is a native macOS Swift application that allows you to locally generate incredible, high-quality images using the **FLUX.2 Klein 9B** model powered by Apple's MLX framework.

It features a built-in SwiftUI studio interface for generation and a gallery for viewing and lightly editing your creations.

### Examples

**Standard Generation (4 Steps)**
![KleinStudio 4 Steps](assets/demo.png)

**High Quality Generation (40 Steps)**
![KleinStudio 40 Steps](assets/demo_40steps.png)

## Prerequisites

*   A Mac with **Apple Silicon** (M1/M2/M3/M4)
*   macOS 14.0+ (Sonoma or later)
*   **16GB+ Unified Memory** is highly recommended (the model runs in 4-bit, taking ~9GB of RAM)
*   **~60GB of free disk space** for the initial model download and quantized cache.
*   [Python 3.10+](https://www.python.org/downloads/)
*   [Swift & Xcode Command Line Tools](https://developer.apple.com/xcode/)

## Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/yourusername/KleinStudio.git
   cd KleinStudio
   ```

2. **Run the setup script:**
   This script will create a Python virtual environment, install the MLX dependencies, and download/quantize the FLUX.2 Klein 9B model into an optimized 4-bit local cache so you don't blow out your RAM.
   
   *Note: This will take a few minutes as it downloads ~49GB of weights from Hugging Face before compressing them to ~9GB.*
   ```bash
   ./setup.sh
   ```

## Usage

Once setup is complete, you can launch the application directly from the terminal. 

```bash
swift run
```

*   **Studio:** Enter your prompt, tweak your inference steps and guidance scale, and hit generate!
*   **Library:** View all your generated images (saved in `~/Pictures/KleinStudio`). You can right-click to edit brightness, contrast, and saturation!

## How it works

- **Frontend:** Pure SwiftUI. It manages a hidden background Python process (`uvicorn` server) using `Process()`.
- **Backend:** A lightweight `FastAPI` server located in the `backend/` folder. It uses `mflux` to interface directly with the Apple Silicon Neural Engine via `mlx.core`.

## Troubleshooting

- **Memory Leaks:** The backend explicitly clears the MLX Metal cache after every generation, ensuring your system memory recovers immediately.
- **Can't type in the prompt box:** Make sure you launch the app using `swift run` and keep it in the foreground. The app is set to `.regular` activation policy so it correctly steals key focus from the terminal.

## License

MIT License. See [LICENSE](LICENSE) for details.
