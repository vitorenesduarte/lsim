source("util.R")
source("generic.R")

TO_KEEP <- "'(460|490)'"

get_lines <- function(clusters, key, file_index) {
  map(clusters, function(cluster) {
    files <- system(cluster, intern=TRUE)

    # skip if no file
    if(length(files) == 2) { json(c(files[file_index]))[[key]] }
    else { any_non_zero }
  })
}

get_all_lines <- function(clusters, key) {
  lines_y <- list()
  lines_y[[1]] <- (get_lines(clusters, key, 1) / get_lines(clusters, key, 2) * 100) - 100
  lines_y
}

# draw!
main <- function() {
  output_file <- "retwis_processing.png"

  clusters <- c(
    "ls -d processed/* | grep ~50~0~retwis",
    "ls -d processed/* | grep ~75~0~retwis",
    "ls -d processed/* | grep ~100~0~retwis",
    "ls -d processed/* | grep ~125~0~retwis",
    "ls -d processed/* | grep ~150~0~retwis"
  )
  clusters <- map(clusters, function(c) {
      paste(c, " | grep -E ", TO_KEEP, sep="")
  })

  # avoid scientific notation
  options(scipen=999)

  # open device
  png(filename=output_file, width=550, height=300, res=130)

  # change outer margins
  op <- par(
    oma=c(4,3.5,1,1.5),   # room for the legend
    mfrow=c(1,1),      # 2x4 matrix
    mar=c(0, 0, 0, 0) # spacing between plots
  )

  # style stuff
  colors <- c(
    "springgreen4"
  )

  coefs <- c(0.5, 0.75, 1, 1.25, 1.5)
  lines_x <- list()
  lines_x[[1]] <- coefs
  x_lab <- "Zipf coefficients"

  # first plot
  key <- "processing"
  y_lab <- "CPU overhead (%)"
  lines_y <- get_all_lines(clusters, key)
  ytick <- round(lines_y[[1]])

  print(lines_y[[1]] / 100)

  plot_lines_retwis(lines_x, lines_y, colors,
                    x_lab=x_lab,
                    y_lab=y_lab,
                    log="",
                    las=0,
                    digits=0,
                    lwd=2)
  polygon(
    c(min(lines_x[[1]]), lines_x[[1]], max(lines_x[[1]])),
    c(min(lines_y[[1]]), lines_y[[1]], min(lines_y[[1]])),
    col=rgb(37/255,211/255,102/255,0.2),
    border=F
  )


  # close device
  dev.off()
}

main()
warnings()
