import subprocess
import tempfile
from pathlib import Path
from typing import List, Optional


class VideoConcatenator:
    """
    FFmpeg tabanlı video birleştirme iskeleti.

    Not (GPU): Şimdilik CPU/FFmpeg komutlarıyla tasarlanmıştır.
    İleride NVENC / CUDA hızlandırma veya Stable Diffusion video pipeline'ları eklenecekse
    container'a GPU runtime ve uygun ffmpeg build gerekebilir.
    """

    def __init__(self, ffmpeg_bin: str = "ffmpeg"):
        self.ffmpeg_bin = ffmpeg_bin

    def render(self, input_videos: List[Path], output_path: Path, *, reencode: bool = True) -> None:
        """
        input_videos listesini FFmpeg concat demuxer ile birleştirip output_path'e yazar.
        """
        if not input_videos:
            raise ValueError("input_videos cannot be empty")

        missing = [str(p) for p in input_videos if not Path(p).exists()]
        if missing:
            raise FileNotFoundError(f"Missing input video(s): {', '.join(missing)}")

        output_path.parent.mkdir(parents=True, exist_ok=True)

        list_file_path: Optional[Path] = None
        try:
            with tempfile.NamedTemporaryFile("w", suffix=".txt", delete=False) as tmp:
                list_file_path = Path(tmp.name)
                for video in input_videos:
                    # Escape single quotes for ffmpeg concat list format.
                    safe = str(Path(video).resolve()).replace("'", "'\\''")
                    tmp.write(f"file '{safe}'\n")

            cmd = [
                self.ffmpeg_bin,
                "-y",
                "-f",
                "concat",
                "-safe",
                "0",
                "-i",
                str(list_file_path),
            ]
            if reencode:
                cmd.extend(["-c:v", "libx264", "-preset", "veryfast", "-crf", "20", "-c:a", "aac", "-b:a", "192k"])
            else:
                cmd.extend(["-c", "copy"])
            cmd.append(str(output_path.resolve()))

            self._run(cmd)
        finally:
            if list_file_path and list_file_path.exists():
                list_file_path.unlink()

    def _run(self, args: List[str], *, cwd: Optional[Path] = None) -> None:
        proc = subprocess.run(
            args,
            cwd=str(cwd) if cwd else None,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        if proc.returncode != 0:
            raise RuntimeError(f"ffmpeg failed: {proc.stderr}")
