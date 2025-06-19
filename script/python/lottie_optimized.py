import base64
import json
import os
import re
import subprocess
import tempfile
import argparse
from typing import Optional


# 压缩图像为webp格式
# 如果压缩后的大小比原来大，那么会返回None
def img_to_webp(in_data: bytes) -> Optional[bytes]:
    fd, in_path = tempfile.mkstemp()
    try:
        # 写入到临时文件
        with os.fdopen(fd, 'wb') as f:
            f.write(in_data)
        # https://developers.google.com/speed/webp/docs/cwebp?hl=zh-cn
        command = ['cwebp', '-quiet', '-q', '75', '-m', '6', '-o', '-', '--', in_path]
        # 调用pngquant并重定向输入和输出
        process = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=subprocess.PIPE)
        output, error = process.communicate()
        # 等待进程完成，并获取退出码
        return_code = process.wait()
        # 退出码不为0，执行失败
        if return_code != 0:
            return None
        # 数据比原来的小，才算成功
        if len(output) < len(in_data):
            return output
        else:
            return None
    finally:
        # 删除临时文件
        os.remove(in_path)


# 压缩png图像
def png_quant(in_data: bytes) -> Optional[bytes]:
    # 命令行参数
    command = ['pngquant', '--quality=60-80', '--speed=1', '--strip', '--skip-if-larger', '-']
    # 调用pngquant并重定向输入和输出
    process = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=subprocess.PIPE)
    output, _ = process.communicate(input=in_data)
    # 等待进程完成，并获取退出码
    return_code = process.wait()
    # 退出码不为0，执行失败
    if return_code != 0:
        return None
    if len(output) < len(in_data):
        return output
    else:
        return None


def encode_image(img_format: str, data: bytes):
    return f"data:image/{img_format};base64,{base64.b64encode(data).decode()}"


# 压缩lottie文件
def compress_lottie(lottie: dict, output: str):
    # https://lottiefiles.github.io/lottie-docs/assets/
    assets: list = lottie["assets"]
    if assets is not None:
        for item in assets:
            # e	0-1 integer 文件是否嵌入
            if item.get("e") == 1:
                asset_data = item["p"]
                results = re.match(r"data:image/(?P<format>\w+);base64,(?P<data>\S+)", asset_data).groupdict()
                if results is None:
                    continue
                file_format = results["format"]
                base64_data = results["data"]
                byte_data = base64.b64decode(base64_data)

                # 分别用webp和png压缩一遍，取最小的
                webp_data = img_to_webp(byte_data)
                # 如果压缩出来的png比webp小，那就用png
                if file_format == 'png':
                    png_data = png_quant(byte_data)
                else:
                    png_data = None

                if png_data and webp_data:
                    if len(png_data) < len(webp_data):
                        item["p"] = f"data:image/png;base64,{base64.b64encode(png_data).decode()}"
                    else:
                        item["p"] = f"data:image/webp;base64,{base64.b64encode(webp_data).decode()}"
                elif png_data is not None:
                    item["p"] = f"data:image/png;base64,{base64.b64encode(png_data).decode()}"
                elif webp_data is not None:
                    item["p"] = f"data:image/webp;base64,{base64.b64encode(webp_data).decode()}"
    json_result = json.dumps(lottie, separators=(',', ':'), ensure_ascii=False)
    with open(output, "w") as f:
        f.write(json_result)
        f.close()


def load_lottie_file(file_path: str) -> Optional[dict]:
    if not file_path.endswith(".json"):
        return None
    with open(file_path, 'r', encoding='utf-8') as lottie_file:
        lottie = json.load(lottie_file)
    # https://lottiefiles.github.io/lottie-docs/animation/
    # 以下是 Lottie JSON 文件中一些关键的必需字段：
    # fr: 动画的帧率。
    # w: 动画的宽度。
    # h: 动画的高度。
    # layers: 一个包含所有动画层的数组。每个层都有自己的属性，如位置、缩放、旋转、锚点、透明度等，并且可能有自己的嵌套层。
    required_fields = ["v", "fr", "w", "h", "layers"]
    if all(field in lottie for field in required_fields):
        return lottie
    else:
        # raise ValueError(f"错误：无效的lottie文件：{file_path}")
        return None


# 寻找json文件进行处理
def process_file(file_path):
    lottie = load_lottie_file(file_path)
    if lottie is not None:
        compress_lottie(lottie=lottie, output=file_path)


def main():
    parser = argparse.ArgumentParser(description="这个脚本用于压缩lottie文件")
    # 'paths' 是一个位置参数，它会收集所有提供的文件路径到一个列表中
    parser.add_argument('paths', metavar='PATH', type=str, nargs='+', help='需要处理的文件路径列表')
    args = parser.parse_args()
    # 对文件路径列表进行处理
    for path in args.paths:
        # 处理文件
        if os.path.isfile(path):
            process_file(path)
        elif os.path.isdir(path):
            for root_dir, directories, files in os.walk(path):
                for file in files:
                    file_path = os.path.join(root_dir, file)  # 获取文件的完整路径
                    process_file(file_path)
        else:
            raise ValueError(f"错误: 指定的路径 '{path}' 既不是文件也不是目录，或者它不存在。")


# Press the green button in the gutter to run the script.
if __name__ == '__main__':
    main()
