# 本仓库兼容处理：关闭 QSharedMemory 单实例检测，保留其余启动逻辑。
from pathlib import Path
import sys

root = Path(sys.argv[1])
media_tools_path = root / "StandAlone/src/mediatools.cpp"
text = media_tools_path.read_text()
old_single_instance = '''bool MediaToolsPrivate::isSecondInstance()
{
#if QT_CONFIG(sharedmemory)
    return !this->m_singleInstanceSM.create(1024)
           && this->m_singleInstanceSM.error() == QSharedMemory::AlreadyExists;
#else
    return false;
#endif
}'''
new_single_instance = '''bool MediaToolsPrivate::isSecondInstance()
{
    return false;
}'''
if old_single_instance not in text:
    raise SystemExit("mediatools.cpp 中找不到 QSharedMemory 单实例检测代码")
media_tools_path.write_text(text.replace(old_single_instance, new_single_instance, 1))
