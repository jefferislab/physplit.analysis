context('finite population sampling')

test_that("sample_finite_population",{
  expect_equal(sample_finite_population(n = 100, N=100, npositive = 0), 0L)
  expect_equal(sample_finite_population(n = 100, N=100, npositive = 5), 5L)
  expect_equal(sample_finite_population(n = 100, N=100, npositive = 100, replicates = 10),
               rep(100L,10))
})

test_that("sample_finite_population",{
  expect_is(tps <- truepos_given_sample(samplepos = 2, n=10, N=48), 'truepos')
  expect_is(summary(tps), 'table')
})
