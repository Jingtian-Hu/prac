# 从照片算褐变 %：果皮掩膜 + “相对周围最亮黄皮的变暗程度”阈值
# 阈值只用试点香蕉的照片调，分两版：
#   v1：今晚只用试点第 0 天照片调 -> commit -> 算全部第 0 天照片 -> 供 02_randomize.R 配对
#   v2：用试点第 0–2 天照片微调（褐斑更多，阈值更可靠）-> commit -> 算所有天的结果，
#       包括重算第 0 天（作为协变量 brown0）。实验香蕉的随访照片只用 v2 处理。
#
# 11/3 用 18 根练习照片实测后两次修订：
#   (1) 原来的“v < 0.55 且 h < 0.11”会把台灯阴影里的黄皮判成褐色（黄皮色相中位数本来就≈0.11）。
#   (2) 改成“比周围果皮平均亮度暗 20%”后，密集褐斑区里周围平均值本身就是褐色的，参照被拉低，
#       漏判一大片（06_b 肉眼约 40% 只算出 26%）。
#   现在的做法：
#   果皮 = 饱和度高的黄/橙像素（s > peel_s, h < peel_h）+ 紧挨果皮的很暗像素（黑斑）；
#          去掉画面四周 margin 的边框（桌边），再向内腐蚀 erode 像素去掉轮廓边上的过渡像素
#   参照 = 每个像素周围 (2w-1)×(2w-1) 窗口（step=2 时约 1 cm）内最亮的果皮像素（先 5px 平滑去高光）
#          ≈ 这一带“干净黄皮”的亮度，所以不受单侧台灯阴影影响，褐斑再密也有参照
#   褐色 = （亮度 < k × 参照 且 色相 < yellow_h），或色相 < brown_h（偏红褐），或亮度 < dark_v（黑斑）
#          色相门槛 yellow_h 是为了少把棱线和背光面的阴影算进去：阴影里的黄皮色相多在 0.115 以上，
#          褐斑多在 0.115 以下（有重叠，去不干净）
#   在 32 根练习香蕉 64 张照片上，这个 % 与肉眼 1–5 分的 Spearman 相关 ≈ 0.78（非有机 0.83；
#   有机那批几乎没斑、肉眼分差小，只有 0.5）。干净香蕉仍会因棱线阴影算出 5–15% 的底数，
#   正式实验加柔光或两盏灯可以压低。
#   “平均 RGB / 平均亮度”类指标与肉眼只有 0.2–0.3（被阴影和曝光主导），不采用。
THRESHOLD_VERSION <- "v1"
library(jpeg)

PARAMS <- list(step = 2, peel_s = 0.4, peel_h = 0.2, dark_v = 0.3, brown_h = 0.09, yellow_h = 0.115,
               k = 0.75, w = 32, smooth = 5, erode = 4, margin = 0.04)

boxmean <- function(m, k) {   # k×k 窗口内求和（积分图），边缘自动截断
  n <- nrow(m); p <- ncol(m); r <- k %/% 2
  I <- matrix(0, n + 1, p + 1); I[-1, -1] <- t(apply(apply(m, 2, cumsum), 1, cumsum))
  r1 <- pmax(1, 1:n - r); r2 <- pmin(n, 1:n + r); c1 <- pmax(1, 1:p - r); c2 <- pmin(p, 1:p + r)
  I[r2 + 1, c2 + 1] - I[r1, c2 + 1] - I[r2 + 1, c1] + I[r1, c1]
}

locmax <- function(M, w) {    # 每个像素周围 (2w-1)×(2w-1) 窗口内的最大值（分离式，步长倍增）
  run <- function(M, down) { F <- M; s <- 1
    while (s < w) { n <- nrow(F)
      sh <- if (down) rbind(F[-(1:s), , drop = FALSE], matrix(0, s, ncol(F))) else rbind(matrix(0, s, ncol(F)), F[1:(n - s), , drop = FALSE])
      F <- pmax(F, sh); s <- s * 2 }
    F }
  M <- pmax(run(M, TRUE), run(M, FALSE)); t(pmax(run(t(M), TRUE), run(t(M), FALSE)))
}

classify <- function(file, p = PARAMS) {
  img <- readJPEG(file)
  img <- img[seq(1, dim(img)[1], p$step), seq(1, dim(img)[2], p$step), ]   # 降采样省内存
  d <- dim(img)
  hsv <- rgb2hsv(as.vector(img[, , 1]), as.vector(img[, , 2]), as.vector(img[, , 3]), maxColorValue = 1)
  h <- hsv["h", ]; s <- hsv["s", ]; v <- hsv["v", ]
  sat   <- s > p$peel_s & h < p$peel_h
  near  <- as.vector(boxmean(matrix(as.numeric(sat), d[1], d[2]), 31)) > 0.3 * 31^2
  inner <- as.vector(outer(1:d[1], 1:d[2], function(i, j)
    i > p$margin * d[1] & i < (1 - p$margin) * d[1] & j > p$margin * d[2] & j < (1 - p$margin) * d[2]))
  peel0 <- (sat | v < p$dark_v) & near & inner
  kk    <- 2 * p$erode + 1
  peel  <- peel0 & as.vector(boxmean(matrix(as.numeric(peel0), d[1], d[2]), kk)) >= kk^2 - 0.5   # 腐蚀
  vs    <- boxmean(matrix(v * peel0, d[1], d[2]), p$smooth) / pmax(boxmean(matrix(as.numeric(peel0), d[1], d[2]), p$smooth), 1)
  ref   <- as.vector(locmax(vs * matrix(peel0, d[1], d[2]), p$w))
  ratio <- v / pmax(ref, 1e-6)
  brown <- peel & ((ratio < p$k & h < p$yellow_h) | h < p$brown_h | v < p$dark_v)
  list(img = img, d = d, h = h, v = v, ratio = ratio, peel = peel, brown = brown)
}

# 褐变 %：褐色像素 / 果皮像素
brown_pct <- function(file, p = PARAMS) { r <- classify(file, p); 100 * sum(r$brown) / sum(r$peel) }

# 连续褐度（次要指标，不用阈值）：果皮像素比“周围最亮黄皮的 90%”还暗多少，平均后 ×100
# 0 = 整根和干净黄皮一样亮；褐斑越多越深，数值越大。与肉眼评分相关 ≈ 0.75–0.8
brown_index <- function(file, p = PARAMS) { r <- classify(file, p); 100 * mean(pmax(0, 0.9 - r$ratio[r$peel]) / 0.9) }

# 绿度：非褐色果皮像素的平均色相（黄 ≈ 0.12–0.17，绿 ≈ 0.20–0.30，越大越绿）
# 只用于配对排序的次要依据（基线褐变相同的香蕉之间按生熟区分）
peel_hue <- function(file, p = PARAMS) { r <- classify(file, p); mean(r$h[r$peel & !r$brown]) }

# 文件名约定：data/photos/day4/07_a.jpg（香蕉 07，a/b 两面）
# 调阈值用：判为褐色的像素染红、非果皮区域染蓝，另存一张图，肉眼核对
check_overlay <- function(file, out, ...) {
  p <- modifyList(PARAMS, list(...)); r <- classify(file, p); img <- r$img
  m <- matrix(r$brown, r$d[1], r$d[2]); np <- matrix(!r$peel, r$d[1], r$d[2])
  for (k in 1:3) { x <- img[, , k]; x[np] <- x[np] * 0.4 + 0.6 * (k == 3); x[m] <- c(1, 0, 0)[k]; img[, , k] <- x }
  writeJPEG(img, out)
  invisible(100 * sum(r$brown) / sum(r$peel))
}
# 例：check_overlay("data/photos/day0/12_a.jpg", "figures/check_12a.jpg", k = 0.7)   # 12 换成试点编号
# 调参时用 check_overlay(..., 参数 = 值) 试；k 越小越严（漏得多），越大越宽（阴影误判多）。确定后改 PARAMS 再 commit

if (sys.nframe() == 0) {   # 用 Rscript 运行时才批量计算；source() 只加载函数
  files <- list.files("data/photos", pattern = "\\.jpe?g$", recursive = TRUE, full.names = TRUE)
  rs <- lapply(files, function(f) { r <- classify(f)
    c(100 * sum(r$brown) / sum(r$peel), 100 * mean(pmax(0, 0.9 - r$ratio[r$peel]) / 0.9), mean(r$h[r$peel & !r$brown])) })
  out <- data.frame(
    id   = as.integer(sub("_.*", "", basename(files))),
    day  = as.integer(sub(".*day(\\d+).*", "\\1", files)),
    side = sub(".*_(a|b)\\..*", "\\1", basename(files)),
    pct  = sapply(rs, `[`, 1),
    idx  = sapply(rs, `[`, 2),
    hue  = sapply(rs, `[`, 3)
  )
  write.csv(out, paste0("data/brown_by_side_", THRESHOLD_VERSION, ".csv"), row.names = FALSE)
  res <- aggregate(cbind(pct, idx, hue) ~ id + day, out, mean)   # 两面平均
  names(res)[3:5] <- c("brown_pct", "brown_index", "hue")
  res$version <- THRESHOLD_VERSION
  write.csv(res, paste0("data/brown_from_photos_", THRESHOLD_VERSION, ".csv"), row.names = FALSE)
}
