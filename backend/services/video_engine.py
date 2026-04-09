import subprocess
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
        Placeholder: input_videos listesini birleştirip output_path'e yazar.

        TODO:
        - concat demuxer için liste dosyası üret
        - reencode=False ise stream copy (-c copy)
        - hata yönetimi ve loglama
        """
        raise NotImplementedError("VideoConcatenator.render is not implemented yet")

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
