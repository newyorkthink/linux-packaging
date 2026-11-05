from pathlib import Path
import sys

root = Path(sys.argv[1])
encoder_path = root / "libAvKys/Plugins/Codecs/Video/Encoders/ffmpeg/src/videoencoderffmpegelement.cpp"
text = encoder_path.read_text()
old_probe = '''bool VideoEncoderFFmpegElementPrivate::isAvailable(const QString &codec) const
{
    qDebug() << "Testing video codec:" << codec;'''
new_probe = '''bool VideoEncoderFFmpegElementPrivate::isAvailable(const QString &codec) const
{
    auto normalizedCodec = codec.toLower();
    if (normalizedCodec.contains("nvenc")
        || normalizedCodec.contains("qsv")
        || normalizedCodec.contains("amf")
        || normalizedCodec.contains("vaapi")
        || normalizedCodec.contains("vulkan")
        || normalizedCodec.contains("v4l2m2m"))
        return false;

    qDebug() << "Testing video codec:" << codec;'''
if old_probe not in text:
    raise SystemExit("videoencoderffmpegelement.cpp 中找不到编码器探测入口")
encoder_path.write_text(text.replace(old_probe, new_probe, 1))
