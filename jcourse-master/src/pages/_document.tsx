import { Head, Html, Main, NextScript } from "next/document";

import Config from "@/config/config";

export default function Document() {
  return (
    <Html lang="zh_CN">
      <Head>
        <link rel="shortcut icon" href="react.svg" />
        <script
          src={`https://hm.baidu.com/hm.js?${Config.BAIDU_TONGJI_CODE}`}
          async
        ></script>
        <meta
          name="description"
          content="SWUFE评课社区，西南财经大学课程点评与经验分享"
        ></meta>
        <meta
          name="keywords"
          content="SWUFE,评课社区,课程点评,西南财经大学,西南财大"
        ></meta>
      </Head>
      <body>
        <Main />
        <NextScript />
      </body>
    </Html>
  );
}
