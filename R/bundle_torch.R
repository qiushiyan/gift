#' @templateVar class a `luz_module_fitted`
#' @template title_desc
#'
#' @templateVar outclass `bundled_luz_module_fitted`
#' @templateVar default .
#' @template return_bundle
#' @family bundlers
#'
#' @param x A `luz_module_fitted` object returned from
#'   [luz::fit.luz_module_generator()].
#' @template param_unused_dots
#'
#' @details
#' For now, bundling methods for torch are only available
#' via the luz package, "a higher level API for torch providing
#' abstractions to allow for much less verbose training loops."
#'
#' These bundlers rely on serialization methods from luz and torch,
#' which are [described by the package authors][torch::torch_save]
#' as "experimental" and not for "use for long term storage."
#'
#' @method bundle luz_module_fitted
#' @rdname bundle_torch
#' @seealso This method adapts [luz::luz_save()] and the internal luz function
#'   `model_to_raw()`, as well as [torch::torch_save()].
#' @examplesIf FALSE
#' # fit model and bundle ------------------------------------------------
#' library(torch)
#' library(torchvision)
#' library(luz)
#'
#' set.seed(1)
#'
#' # example adapted from luz pkgdown article "Autoencoder"
#' dir <- tempdir()
#'
#' mnist_dataset2 <- torch::dataset(
#'   inherit = mnist_dataset,
#'   .getitem = function(i) {
#'     output <- super$.getitem(i)
#'     output$y <- output$x
#'     output
#'   }
#' )
#'
#' train_ds <- mnist_dataset2(
#'   dir,
#'   download = TRUE,
#'   transform = transform_to_tensor
#' )
#'
#' test_ds <- mnist_dataset2(
#'   dir,
#'   train = FALSE,
#'   transform = transform_to_tensor
#' )
#'
#' train_dl <- dataloader(train_ds, batch_size = 128, shuffle = TRUE)
#' test_dl <- dataloader(test_ds, batch_size = 128)
#'
#' net <- nn_module(
#'   "Net",
#'   initialize = function() {
#'     self$encoder <- nn_sequential(
#'       nn_conv2d(1, 6, kernel_size=5),
#'       nn_relu(),
#'       nn_conv2d(6, 16, kernel_size=5),
#'       nn_relu()
#'     )
#'     self$decoder <- nn_sequential(
#'       nn_conv_transpose2d(16, 6, kernel_size = 5),
#'       nn_relu(),
#'       nn_conv_transpose2d(6, 1, kernel_size = 5),
#'       nn_sigmoid()
#'     )
#'   },
#'   forward = function(x) {
#'     x %>%
#'       self$encoder() %>%
#'       self$decoder()
#'   },
#'   predict = function(x) {
#'     self$encoder(x) %>%
#'       torch_flatten(start_dim = 2)
#'   }
#' )
#'
#' mod <- net %>%
#'   setup(
#'     loss = nn_mse_loss(),
#'     optimizer = optim_adam
#'   ) %>%
#'   fit(train_dl, epochs = 1, valid_data = test_dl)
#'
#' mod_bundle <- bundle(mod)
#'
#'
#' # then, after saveRDS + readRDS or passing to a new session ----------
#' mod_unbundled <- unbundle(mod_bundle)
#'
#' mod_unbundled_preds <- predict(mod_unbundled, test_dl)
#'
#' @aliases bundle.luz_module_fitted
#' @export
bundle.luz_module_fitted <- function(x, ...) {
  rlang::check_installed("luz")
  rlang::check_installed("torch")
  rlang::check_dots_empty()

  res <- x

  # see luz::luz_save and luz:::model_to_raw
  suppressWarnings({
    con <- rawConnection(raw(), open = "wr")
    torch::torch_save(res$model, con)
    serialized_model <- rawConnectionValue(con)
    res$ctx$.serialized_model <- serialized_model
    res$ctx$.serialization_version <- 2L
  })

  close(con)

  bundle_constr(
    object = res,
    situate = situate_constr(function(object) {
      # see luz::luz_load and luz:::model_from_raw
      con <- rawConnection(object$ctx$.serialized_model)
      on.exit({
        close(con)
      }, add = TRUE)
      res <- torch::torch_load(con)

      object$model <- res
      object$ctx$.serialized_model <- NULL
      object$ctx$.serialization_version <- NULL

      structure(object, class = !!class(x))
    }),
    desc_class = class(x)[1],
    pkg_versions = c("luz" = utils::packageVersion("luz"))
  )
}
